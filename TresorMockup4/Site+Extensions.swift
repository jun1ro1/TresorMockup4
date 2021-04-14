//
//  Site+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//
// https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9

import Foundation
import CoreData

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
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        self.observation = self.observe(\.password, options: [.new, .old], changeHandler: Self.updatePassword)
    }
    
    private static func updatePassword(site: Site, change: NSKeyValueObservedChange<String?>) {
        guard let newPass = change.newValue as? String    else { return }
        guard let oldPass = change.oldValue as? String    else { return }
        guard newPass != oldPass                          else { return }
        guard let viewContext = site.managedObjectContext else { return }
        
        // BUG site.passwords is empty
        let passwords = (site.passwords?.allObjects as? [Password] ?? [])
                .sorted { (x, y) -> Bool in
                    let xp = x.password ?? ""
                    let yp = y.password ?? ""
                    if xp != yp {
                        return xp < yp
                    }
                    let xc = x.createdAt ?? Date(timeIntervalSince1970: 0)
                    let yc = y.createdAt ?? Date(timeIntervalSince1970: 0)
                    return xc < yc
                }
        
        
        let cryptor = Cryptor(name: "DEBUG")
        try? cryptor.open(password: "pass")
        let newPassPlain = try? cryptor.decrypt(cipher: newPass)
        let oldPassPlain = try? cryptor.decrypt(cipher: oldPass)
        J1Logger.shared.debug("newPass = \(newPass) newPassPlain = \(String(describing: newPassPlain))")
        J1Logger.shared.debug("oldPass = \(oldPass) oldPassPlain = \(String(describing: oldPassPlain))")
        try? cryptor.close()
        
        
        // search oldpassword
        if passwords.first(where: { $0.password == oldPass }) == nil {
            let oldPassword = Password(context: viewContext)
            oldPassword.password = oldPass
            oldPassword.site     = site
            site.addToPasswords(oldPassword)
        }

        let newPassword = { () -> Password in
            var p = passwords.first(where: { $0.password == newPass })
            if p != nil { return p! }
            p = Password(context: viewContext)
            p!.password = newPass
            p!.site     = site
            site.addToPasswords(p!)
            return p!
        }()
        newPassword.select()
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
    
    class func backup(url: URL) -> URL {
        let fileURL = url
            .appendingPathComponent(String(describing: Self.self), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)
        Self.backup(url: fileURL, sortNames: ["titleSort", "title", "url", "userid", "password"])
        return fileURL
    }
}
