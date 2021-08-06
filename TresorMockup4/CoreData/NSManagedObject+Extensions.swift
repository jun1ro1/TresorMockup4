//
//  NSManagedObject+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/05.
//

import Foundation
import CoreData
import Combine

let ManagedObjectVersion = 1

extension NSManagedObject {
    static let dateFormatter = ISO8601DateFormatter()
    
    convenience init<Value>(from properties: [String: Value],
                            context: NSManagedObjectContext)
    where Value: StringProtocol {
        self.init(context: context)
        let names = Self.entity().properties.map { $0.name }
        names.forEach { name in
            if let value = properties[name] as? String {
                switch Self.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    let val = Bool(value)
                    if let old = self.primitiveValue(forKey: name) as? Bool, old == val { return }
                    self.setPrimitiveValue(val, forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    let val = Int(value)
                    if let old = self.primitiveValue(forKey: name) as? Int, old == val { return }
                    self.setPrimitiveValue(val, forKey: name)
                case .dateAttributeType:
                    let val = Self.dateFormatter.date(from: value)
                    if let old = self.primitiveValue(forKey: name) as? Date, old == val { return }
                    self.setPrimitiveValue(val, forKey: name)
                case .stringAttributeType:
                    let val = value
                    if let old = self.primitiveValue(forKey: name) as? String, old == val { return }
                    self.setPrimitiveValue(val, forKey: name)
                default:
                    self.setPrimitiveValue(nil, forKey: name)
                }
            }
        }
    }
    
    func setPrimitive(from properties: [String: String]) {
        let names = Self.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] {
                switch Self.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    self.setPrimitiveValue(Bool(val), forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    self.setPrimitiveValue(Int(val), forKey: name)
                case .dateAttributeType:
                    self.setPrimitiveValue(Self.dateFormatter.date(from: val), forKey: name)
                case .UUIDAttributeType:
                    if let v = UUID(uuidString: val) {
                        self.setPrimitiveValue(v, forKey: name)
                    } else {
                        J1Logger.shared.error("can not convert to UUID \(val)")
                    }
                case .stringAttributeType:
                    self.setPrimitiveValue(String(val), forKey: name)
                default:
                    self.setPrimitiveValue(nil, forKey: name)
                }
            }
        }
    }

    func setValues(from properties: [String: String]) {
        let names = Self.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] {
                switch Self.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    self.setValue(Bool(val), forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    self.setValue(Int(val), forKey: name)
                case .dateAttributeType:
                    self.setValue(Self.dateFormatter.date(from: val), forKey: name)
                case .UUIDAttributeType:
                    if let v = UUID(uuidString: val) {
                        self.setValue(v, forKey: name)
                    } else {
                        J1Logger.shared.error("can not convert to UUID \(val)")
                    }
                case .stringAttributeType:
                    self.setValue(String(val), forKey: name)
                default:
                    self.setValue(nil, forKey: name)
                }
            }
        }
    }

    func propertyDictionary() -> [String: String] {
        let props = Self.entity().properties
        
        let attrs: [(String, String)?] = props.map { prop -> (String, String)? in
            guard let attr = prop as? NSAttributeDescription else {
                return nil
            }
            let name = attr.name
            let typ  = attr.attributeType
            let val  = self.value(forKey: name)
            var str: String = ""
            switch (typ, val) {
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
                str = ""
            }
            return (name, str)
        }
        
        let rels: [(String, String)?] =  props.map { prop -> (String, String)? in
            guard let rel = prop as? NSRelationshipDescription else {
                return nil
            }
            let name  = rel.name
            guard !rel.isToMany else {
                return nil
            }
            
            let val   = self.value(forKey: name) as? NSManagedObject
            let uuid  = val?.value(forKey: "uuid") as? UUID
            
            let str = uuid?.uuidString
            return (name, str ?? "")
        }
        
        return Dictionary(uniqueKeysWithValues: (attrs + rels).compactMap { $0 } )
    }

    func relationNames() -> [String] {
        let props = Self.entity().properties
        return props.compactMap { prop -> String? in
            (prop as? NSRelationshipDescription)?.name
        }
    }
}

// MARK: -
extension NSManagedObject {
    // https://stackoverflow.com/questions/24658641/ios-delete-all-core-data-swift
    // https://www.avanderlee.com/swift/nsbatchdeleterequest-core-data/
    // https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud
    class func deleteAll(predicate: NSPredicate? = nil) {
        let name = Self.entity().name!
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: name)
        if predicate != nil {
            request.predicate = predicate
        }
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let count  = result?.result as? NSNumber
                J1Logger.shared.debug("batch delete request name = \(name) result = \(String(describing: count))")
            } catch let error {
                J1Logger.shared.error("batch delete request = \(error)")
            }
        }
    }
}

// MARK: -
extension NSManagedObject: PublishableManagedObject {
    class func publisher(sortNames: [String] = [], predicate: NSPredicate? = nil)
    -> AnyPublisher<[String: String]?, Error> {
        let names    = Self.entity().properties.map { $0.name }
        var snames   = sortNames
        let unknowns = Set(snames).subtracting(Set(names))
        if unknowns != [] {
            J1Logger.shared.error("\(sortNames) have unknown names \(unknowns)")
            snames.removeAll { unknowns.contains($0) }
        }
        
        let viewContext = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Self> = NSFetchRequest(entityName: Self.entity().name!)
        request.predicate = predicate
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
            return Fail<[String: String]?, Error>(error: error).eraseToAnyPublisher()
        }
        
        let pub = Publishers.Sequence<[[String: String]?], Error>(sequence: mobjects.map {
            $0.propertyDictionary()
        })
        return pub.eraseToAnyPublisher()
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
