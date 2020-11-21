//
//  Password+CoreDataProperties.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//
//

import Foundation
import CoreData


extension Password {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Password> {
        return NSFetchRequest<Password>(entityName: "Password")
    }

    @NSManaged public var active: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var current: Bool
    @NSManaged public var password: String?
    @NSManaged public var selectedAt: Date?
    @NSManaged public var uuid: String?
    @NSManaged public var sites: Site?

}

extension Password : Identifiable {

}
