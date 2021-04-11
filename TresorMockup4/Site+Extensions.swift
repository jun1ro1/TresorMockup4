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
        
        // search oldpassword
        let passwords = site.passwords
        if passwords == nil || passwords!.filtered(using: NSPredicate(format: "password == %@", oldPass)) == [] {
            let oldPassword = Password(context: viewContext)
            oldPassword.password = oldPass
            oldPassword.site     = site
        }
        let newPassword = Password(context: viewContext)
        newPassword.password = newPass
        newPassword.site     = site
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
