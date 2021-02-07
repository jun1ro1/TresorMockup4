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
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(Date(), forKey: "selectedAt")
        self.setPrimitiveValue(UUID().uuidString, forKey: "uuid")
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
