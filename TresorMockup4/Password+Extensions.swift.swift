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
    func select(site: Site){
        let now = Date()
        self.selectedAt = now
        site.selectAt   = now
        site.password   = self.password
        (site.passwords?.allObjects as? [Password])?.forEach { pass in
            if pass.current {
                pass.current = false
            }
        }
        self.current = true
        self.site    = site
    }
}

extension Password {
    class func backup() -> URL? {
        let url = FileManager.default.temporaryDirectory
        let fileURL = url
            .appendingPathComponent(String(describing: Self.self), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)
        
        Self.backup(url: fileURL, sortNames: ["selectedAt", "password"])
        return fileURL
    }
}
