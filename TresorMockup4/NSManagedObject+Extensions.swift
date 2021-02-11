//
//  NSManagedObject+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/05.
//

import Foundation
import CoreData

let ManagedObjectVersion = 1

extension NSManagedObject {
    convenience init<Value>(from properties: [String: Value],
                            context: NSManagedObjectContext)
    where Value: StringProtocol {
        self.init(context: context)
        let dateFormatter = ISO8601DateFormatter()
        let names = Self.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] as? String {
                switch Self.entity().attributesByName[name]?.attributeType {
                case .booleanAttributeType:
                    self.setValue(Bool(val), forKey: name)
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    self.setValue(Int(val), forKey: name)
                case .dateAttributeType:
                    self.setValue(dateFormatter.date(from: val), forKey: name)
                case .stringAttributeType:
                    self.setValue(String(val), forKey: name)
                default:
                    self.setValue(nil, forKey: name)
                }
            }
        }
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
