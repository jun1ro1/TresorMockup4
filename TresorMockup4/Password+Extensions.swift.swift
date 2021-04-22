//
//  File.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/06.
//
// https://www.hackingwithswift.com/books/ios-swiftui/one-to-many-relationships-with-core-data-swiftui-and-fetchrequest

import Foundation

extension Password {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")
        self.setPrimitiveValue(now, forKey: "selectedAt")
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
    }

    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
}

extension Password {
    func toCurrent() {
        guard let site = self.site else { return }
        let now = Date()
        self.selectedAt = now
        _ = site.passwords?.map {
            guard let pass = $0 as? Password else { return }
            if pass.current {
                pass.current = false
            }
        }
        self.current = true

        site.selectAt   = now
        site.setPrimitiveValue(self.password, forKey: "password")
    }
    
    func select() {
        guard let site = self.site else { return }
        let bag = PasswordProxy(password: self)
        bag.setTo(site: site)
    }
}

extension Password {
    class func backup(url: URL) -> URL {
        let fileURL = url
            .appendingPathComponent(String(describing: Self.self), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)        
        Self.backup(url: fileURL, sortNames: ["selectedAt", "password"])
        return fileURL
    }
}
