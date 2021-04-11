//
//  Category+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/08.
//
// https://stackoverflow.com/questions/28620794/swift-nspredicate-throwing-exc-bad-accesscode-1-address-0x1-when-compounding

import Foundation
import CoreData
import SwiftUI

enum CategoryKind: Int16 {
    case all   =    0
    case trash =   -1
    case none  = -999
}

extension Category {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
    }

    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
    
    var categoryKind: CategoryKind {
        if let val = (self.primitiveValue(forKey: "kind") as? Int16) {
            return CategoryKind(rawValue: val)!
        } else {
            return .none
        }
    }
}

extension Category {
    private static var All_private:   Category? = nil
    static var All:   Category? {
        get {
            if self.All_private == nil {
                self.All_private = CategoryManager.shared.singleton(kind: .all, name: "All")
            }
            return self.All_private
        }
    }
    private static var Trash_private: Category? = nil
    static var Trash: Category? {
        get {
            if self.Trash_private == nil {
                self.Trash_private = CategoryManager.shared.singleton(kind: .trash, name: "Trash")
            }
            return self.Trash_private
        }
    }

    class func deleteAll() {
        let predicate =
            NSPredicate(format: "kind != %@ AND kind != %@",
                        NSNumber(value: CategoryKind.all.rawValue), NSNumber(value: CategoryKind.trash.rawValue))
        self.All_private   = nil
        self.Trash_private = nil
        super.deleteAll(predicate: predicate)
    }

    class func backup() -> URL? {
        let url = FileManager.default.temporaryDirectory
        let fileURL = url
            .appendingPathComponent(String(describing: Self.self), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)
        
        Self.backup(url: fileURL, sortNames: ["kind", "nameSort", "name"])
        return fileURL
    }
}

// MARK: -
class CategoryManager {
    private var viewContext = PersistenceController.shared.container.viewContext
    
    static private var shared_private: CategoryManager? = nil
    static var shared: CategoryManager {
        if Self.shared_private == nil {
            Self.shared_private = CategoryManager()
        }
        return Self.shared_private!
    }
    
    fileprivate func singleton(kind: CategoryKind, name: String) -> Category? {
        let req: NSFetchRequest<Category> = NSFetchRequest(entityName: Category.entity().name!)
        req.predicate = NSPredicate(format: "kind = %@", NSNumber(value: kind.rawValue))
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Category.createdAt, ascending: false)]
    
        var result: [Category] = []
        do {
            result = try self.viewContext.fetch(req)
        } catch let error {
            J1Logger.shared.error("fetch error = \(error)")
            result = []
        }
        
        var cat: Category? = nil
        let count = result.count
        switch count {
        case 0:
            cat = Category(context: self.viewContext)
            cat?.kind     = Int16(kind.rawValue)
            cat?.name     = name
            cat?.nameSort = name
            if self.viewContext.hasChanges {
                do {
                    try self.viewContext.save()
                } catch let error {
                    J1Logger.shared.error("save error = \(error)")
                }
            }
        case 1:
            cat = result.first
        case 2...:
            J1Logger.shared.error("kind=\(kind) count=\(count)")
            cat = result.first
        default:
            J1Logger.shared.error("kind=\(kind) count=\(count)")
            cat = result.first
        }
        
        return cat
    }
}
