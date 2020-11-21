//
//  Site+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//

import Foundation
import CoreData

extension Site {
    override public func awakeFromInsert() {
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(UUID().uuidString, forKey: "uuid")
        self.setPrimitiveValue(true, forKey: "active")
    }

    public var currentPassword: Password? {
        return self.passwords?.first {($0 as! Password).current} as? Password
    }
}

extension Site {
    convenience init<Value>(from properties: [String: Value],
                            context: NSManagedObjectContext)
    where Value: StringProtocol
    {
        self.init(context: context)
        let dateFormatter = ISO8601DateFormatter()
        let names = Site.entity().properties.map { $0.name }
        names.forEach { name in
            if let val = properties[name] as? String {
                switch Site.entity().attributesByName[name]?.attributeType {
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
