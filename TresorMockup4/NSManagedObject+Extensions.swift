//
//  NSManagedObject+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/05.
//

import Foundation
import CoreData
import Combine
import CSV

let ManagedObjectVersion = 1

extension NSManagedObject {
    static let dateFormatter = ISO8601DateFormatter()
    
    convenience init<Value>(from properties: [String: Value],
                            context: NSManagedObjectContext)
    where Value: StringProtocol {
        self.init(context: context)
        let names = Self.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] as? String {
                switch Self.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    self.setValue(Bool(val), forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    self.setValue(Int(val), forKey: name)
                case .dateAttributeType:
                    self.setValue(Self.dateFormatter.date(from: val), forKey: name)
                case .stringAttributeType:
                    self.setValue(String(val), forKey: name)
                default:
                    self.setValue(nil, forKey: name)
                }
            }
        }
    }
    
    func stringProperty() -> [String: String] {
        let props = Self.entity().properties
        
        let attrs: [(String, String)?] = props.map { prop -> (String, String)? in
            guard let attr = prop as? NSAttributeDescription else { return nil }
            let name = attr.name
            let ty   = attr.attributeType
            let val  = self.value(forKey: name)
            var str: String? = nil
            switch (ty, val) {
            case (.booleanAttributeType,   let v as Bool):
                str = String(v)
            case (.integer16AttributeType, let v as Int),
                 (.integer32AttributeType, let v as Int),
                 (.integer64AttributeType, let v as Int):
                str = String(v)
            case (.dateAttributeType,      let v as Date):
                str = Self.dateFormatter.string(from: v)
            case (.UUIDAttributeType,      let v as UUID):
                str = v.uuidString
            case (.stringAttributeType,    let v as String):
                str = v
            default:
                str = nil
            }
            return str == nil ? nil : (name, str!)
        }
        
        let rels: [(String, String)?] =  props.map { prop -> (String, String)? in
            guard let rel = prop as? NSRelationshipDescription else { return nil }
            let name  = rel.name
            guard !rel.isToMany else { return nil }
            
            let val   = self.value(forKey: name) as? NSManagedObject
            let uuid  = val?.value(forKey: "uuid") as? UUID
            
            let str = uuid?.uuidString
            return (name, str ?? "")
            
        }
        
        return Dictionary(uniqueKeysWithValues: (attrs + rels).compactMap { $0 } )
    }
}

// MARK: -

extension NSManagedObject {
    class func exportToCSV(url: URL, sortNames: [String] = []) {
        let viewContext = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Self> = NSFetchRequest(entityName: Self.entity().name!)
        let sorts: [NSSortDescriptor] = sortNames.map {
            NSSortDescriptor(key: $0, ascending: true)
        }
        request.sortDescriptors = (sorts == []) ? nil : sorts
        var items: [Self] = []
        do {
            items = try viewContext.fetch(request)
        } catch let error {
            J1Logger.shared.error("fetch error = \(error)")
            items = []
        }
        
        guard let stream = OutputStream(url: url, append: false) else {
            J1Logger.shared.error("OutputStream error url=\(url)")
            return
        }
        
        let csv: CSVWriter
        do {
            csv = try CSVWriter(stream: stream)
        } catch(let error) {
            J1Logger.shared.error("CSVWriter fails=\(error)")
            return
        }
        
        var names:  [String]? = nil
        var snames: [String]  = sortNames
        items.forEach { site in
            let values = site.stringProperty()
            if names == nil {
                names = values.keys.map { $0 }
                if !Set(sortNames).isSubset(of: names!) {
                    J1Logger.shared.error("\(sortNames) is not a subset of \(names!)")
                    snames = []
                }
                let otherNames  = Set(names!).subtracting(sortNames)
                names = snames + otherNames
                J1Logger.shared.debug("names=\(names!)")
                
                do {
                    try csv.write(row: names!)
                } catch let error {
                    J1Logger.shared.error("csv.write error=\(error) names=\(names!)")
                }
            }
            
            csv.beginNewRow()
            names!.forEach { name in
                guard let v = values[name] else {
                    J1Logger.shared.error("value[\(name)] == nil")
                    return
                }
                do {
                    try csv.write(field: v)
                } catch let error {
                    J1Logger.shared.error("csv.write error=\(error) value=\(v)")
                }
            }
        }
        csv.stream.close()
    }
    
    // MARK: -
    
    class func publisher(sortNames: [String] = [])
    -> AnyPublisher<Dictionary<String, String>, Error> {
        let names    = Self.entity().properties.map { $0.name }
        var snames   = sortNames
        let unknowns = Set(snames).subtracting(Set(names))
        if unknowns != [] {
            J1Logger.shared.error("\(sortNames) have unknown names \(unknowns)")
            snames.removeAll { unknowns.contains($0) }
        }
        
        let viewContext = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Self> = NSFetchRequest(entityName: Self.entity().name!)
        let sorts: [NSSortDescriptor] = snames.map {
            NSSortDescriptor(key: $0, ascending: true)
        }
        request.sortDescriptors = (sorts == []) ? nil : sorts
        
        var mobjects: [Self] = []
        do {
            mobjects = try viewContext.fetch(request)
        } catch let error {
            J1Logger.shared.error("fetch error = \(error)")
            mobjects = []
            return Fail<Dictionary<String, String>, Error>(error: error).eraseToAnyPublisher()
        }
        
        let pub = Publishers.Sequence<[Dictionary<String, String>], Error>(sequence: mobjects.map { $0.stringProperty() } )
        return pub.eraseToAnyPublisher()
    }
    
    class func backup(url: URL, sortNames: [String] = []) {
        let publisher = Self.publisher(sortNames: sortNames)
        let headerPublisher: AnyPublisher<[String], Error> =
            publisher.first().map {
                var names    = Array($0.keys)
                var snames   = sortNames
                let unknowns = Set(snames).subtracting(Set(names))
                if unknowns != [] {
                    J1Logger.shared.error("\(sortNames) have unknown names \(unknowns)")
                    snames.removeAll { unknowns.contains($0) }
                }
                let onames  = Set(names).subtracting(snames)
                names = snames + onames
                return names
            }.eraseToAnyPublisher()
        
        let filePublisher = headerPublisher.combineLatest(publisher.prepend([:]))
            .map { (keys, dict) -> [String] in
                dict == [:] ? keys : keys.map { dict[$0] ?? "" }
            }.eraseToAnyPublisher()
        
        guard let stream = OutputStream(url: url, append: false) else {
            J1Logger.shared.error("OutputStream error url=\(url)")
            return
        }
        let csv: CSVWriter
        do {
            csv = try CSVWriter(stream: stream)
        } catch(let error) {
            J1Logger.shared.error("CSVWriter fails=\(error)")
            return
        }
        
        _ = filePublisher.sink { completion in
            csv.stream.close()
            switch completion {
            case .finished:
                J1Logger.shared.debug("finished")
            case .failure(let error):
                J1Logger.shared.error("error = \(error)")
            }
        } receiveValue: { values in
            do {
                try csv.write(row: values)
            } catch let error {
                J1Logger.shared.error("error = \(error)")
            }
        }
    }
    
}


// MARK: -
struct ObjectState: OptionSet, Hashable {
    let rawValue:  Int16
    var hashValue: Int { return Int(self.rawValue) }
    
    init(rawValue: Int16) { self.rawValue = rawValue }
    
    static let editing = ObjectState(rawValue: 0x0001)
    static let saved   = ObjectState(rawValue: 0x0002)
    static let deleted = ObjectState(rawValue: 0x0004)
    
    let mutex: NSLock = NSLock()
    
    static var shared = ObjectState()
}

extension NSManagedObject {
    func isEmptyState() -> Bool {
        ObjectState.shared.mutex.lock()
        let val = self.value(forKey: "state") as? Int16
        ObjectState.shared.mutex.unlock()
        return (val != nil) && (val == 0)
    }
    
    func on(state: ObjectState) {
        ObjectState.shared.mutex.lock()
        if let val = self.value(forKey: "state") as? Int16 {
            var state = ObjectState(rawValue: val)
            _ = state.insert(state)
            self.setValue(state.rawValue, forKey: "state")
        }
        ObjectState.shared.mutex.unlock()
    }
    
    func off(state: ObjectState) {
        ObjectState.shared.mutex.lock()
        if let val = self.value(forKey: "state") as? Int16 {
            var state = ObjectState(rawValue: val)
            state.remove(state)
            self.setValue(state.rawValue, forKey: "state")
        }
        ObjectState.shared.mutex.unlock()
    }
}
