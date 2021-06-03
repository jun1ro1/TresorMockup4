//
//  Site+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//
// https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9

import Foundation
import CoreData
import Combine
import CSV

extension Site {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")        
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
        
        self.setPrimitiveValue(8, forKey: "maxLength")
        self.setPrimitiveValue(CypherCharacterSet.AlphaNumericsSet.rawValue, forKey: "charSet")
        
        // https://developer.apple.com/documentation/objectivec/nsobject/keyvalueobservingpublisher
        // https://developer.apple.com/documentation/swift/cocoa_design_patterns/using_key-value_observing_in_swift
        // https://qiita.com/BlueEventHorizon/items/bf37428b54b937728dc7
        // https://developer.apple.com/documentation/swift/cocoa_design_patterns/using_key-value_observing_in_swift
        // https://stackoverflow.com/questions/60386000/how-to-use-combine-framework-nsobject-keyvalueobservingpublisher
        // https://www.apeth.com/UnderstandingCombine/publishers/publisherskvo.html
        // https://augmentedcode.io/2020/11/08/observing-a-kvo-compatible-model-in-swiftui-and-mvvm/
    }
    
    //    override public func awakeFromFetch() {
    //        super.awakeFromFetch()
    //        self.observation = self.observe(\.password, options: [.new, .old], changeHandler: Self.updatePassword)
    //    }
    
    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
    
    public var currentPassword: Password? {
        return self.passwords?.first {($0 as! Password).current} as? Password
    }
}

// MARK: -
extension Site {
    public func setPassword(cryptor: Cryptor, plain newPassPlain: String) throws {
        guard let viewContext = self.managedObjectContext else { return }
        guard !newPassPlain.isEmpty else { return }
        
        let passwords = (self.passwords?.allObjects as? [Password] ?? [])
            .sorted { (x, y) -> Bool in
                let xc = x.createdAt ?? Date(timeIntervalSince1970: 0)
                let yc = y.createdAt ?? Date(timeIntervalSince1970: 0)
                return xc < yc
            }
                
        let newPassCipher = try cryptor.encrypt(plain: newPassPlain)
        let newPassHash   = try newPassPlain.hash()
        let newPassLength = Int16(newPassPlain.count)
        
        // save old password
        if let oldPassStr  = self.password, let oldPassHash = self.passwordHash {
            if passwords.first(where: { $0.passwordHash == oldPassHash }) == nil {
                let oldPassword = Password(context: viewContext)
                oldPassword.password     = oldPassStr
                oldPassword.passwordHash = self.passwordHash
                oldPassword.length       = self.length
                oldPassword.site         = self
                self.addToPasswords(oldPassword)
            }
        }
        
        // set new password
        self.password     = newPassCipher
        self.passwordHash = newPassHash
        self.length       = newPassLength
        
        let newPassword =
            passwords.first(where: { $0.passwordHash == newPassHash }) ??
            {
                let p = Password(context: viewContext)
                p.password     = self.password
                p.passwordHash = self.passwordHash
                p.length       = self.length
                p.site         = self
                self.addToPasswords(p)
                return p
            }()
        newPassword.toCurrent()
    }
}

// MARK: -
extension Site {
    class func delete(_ site: Site, context: NSManagedObjectContext) {
        site.passwords?.allObjects.forEach { pass in
            context.delete(pass as! NSManagedObject)
        }
        context.delete(site)
    }    
}

extension Site: PrioritizedNameManagedObject {
    static var sortNames: [String] {
        return ["titleSort", "title", "url", "userid", "password", "selectAt"]
    }
}
