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
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")        
        self.setPrimitiveValue(UUID().uuidString, forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
        
        self.setPrimitiveValue(8, forKey: "maxLength")
        self.setPrimitiveValue(CypherCharacterSet.AlphaNumericsSet.rawValue, forKey: "charSet")
    }
    
    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
    
    public var currentPassword: Password? {
        return self.passwords?.first {($0 as! Password).current} as? Password
    }
    
    class func delete(_ site: Site, context: NSManagedObjectContext) {
        site.passwords?.allObjects.forEach { pass in
            context.delete(pass as! NSManagedObject)
        }
        context.delete(site)
    }
}
