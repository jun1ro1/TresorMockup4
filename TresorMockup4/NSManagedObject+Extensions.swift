//
//  NSManagedObject+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/05.
//

import Foundation
import CoreData
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

    static var valuedNames: [String] {
        let props = Self.entity().properties
        return props.map { prop -> String? in
            guard let attr = prop as? NSAttributeDescription else {
                return nil
            }
            return attr.name
        }.compactMap { $0 }
    }
    
    func values() -> [String: String] {
        let names = Self.valuedNames
        return Dictionary(
            uniqueKeysWithValues:
                names.map { name -> (String, String)? in
                    let prop = Self.entity().propertiesByName[name]
                    guard let attr = ( prop as? NSAttributeDescription) else {
                        return nil
                    }
                    let t = attr.attributeType
                    let val = self.value(forKey: name)
                    var str: String? = nil
                    switch t {
                    case .booleanAttributeType:
                        if let v = val as? Bool {
                            str = String(v)
                        }
                    case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                        if let v = val as? Int {
                            str = String(v)
                        }
                    case .dateAttributeType:
                        str = Self.dateFormatter.string(from: val as! Date)
                    case .stringAttributeType:
                        str = val as? String
                    case .UUIDAttributeType:
                        str = (val as? UUID)?.uuidString
                    default:
                        break
                    }
                    return (str == nil ? nil : (name, str!))
                }.compactMap { $0 }
        ) // Dictinoary
    }

    class func exportToCSV(url: URL, sortNames: [String] = []) {
        let viewContext = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Self> = NSFetchRequest(entityName: Self.entity().name!)
        let sorts: [NSSortDescriptor] = sortNames.map {
            NSSortDescriptor(key: $0, ascending: true)
        }
        request.sortDescriptors = sorts
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
            let values = site.values()
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
}

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
