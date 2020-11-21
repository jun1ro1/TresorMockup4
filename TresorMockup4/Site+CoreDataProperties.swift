//
//  Site+CoreDataProperties.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//
//

import Foundation
import CoreData


extension Site {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Site> {
        return NSFetchRequest<Site>(entityName: "Site")
    }

    @NSManaged public var active: Bool
    @NSManaged public var charSet: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var loginAt: Date?
    @NSManaged public var maxLength: Int16
    @NSManaged public var memo: String?
    @NSManaged public var password: String?
    @NSManaged public var pinned: Bool
    @NSManaged public var selectAt: Date?
    @NSManaged public var titile: String?
    @NSManaged public var titleSort: String?
    @NSManaged public var url: String?
    @NSManaged public var user: String?
    @NSManaged public var uuid: String?
    @NSManaged public var passwords: NSSet?

}

// MARK: Generated accessors for passwords
extension Site {

    @objc(addPasswordsObject:)
    @NSManaged public func addToPasswords(_ value: Password)

    @objc(removePasswordsObject:)
    @NSManaged public func removeFromPasswords(_ value: Password)

    @objc(addPasswords:)
    @NSManaged public func addToPasswords(_ values: NSSet)

    @objc(removePasswords:)
    @NSManaged public func removeFromPasswords(_ values: NSSet)

}

extension Site : Identifiable {

}
