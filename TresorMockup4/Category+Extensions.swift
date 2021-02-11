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

extension Category {
    override public func awakeFromInsert() {
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")
        self.setPrimitiveValue(UUID().uuidString, forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
    }

    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
}


enum CategoryKind: Int16 {
    case all   =    0
    case trash =   -1
    case none  = -999
}

class CategoryManager {
    private var viewContext = PersistenceController.shared.container.viewContext
    
    static private var shared_private: CategoryManager? = nil
    static var shared: CategoryManager {
        if Self.shared_private == nil {
            Self.shared_private = CategoryManager()
            Self.shared_private?.setup()
        }
        return Self.shared_private!
    }
    
    static var CategoryAll:   Category? = nil
    static var CategoryTrash: Category? = nil
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: []
    ) var categories: FetchedResults<Category>
    
    private func singleton(kind: CategoryKind, name: String) -> Category? {
        var cat: Category? = nil
        let prd = NSPredicate(format: "kind = %@", NSNumber(value: kind.rawValue))
        let req: FetchRequest<Category> =
            FetchRequest(entity: Category.entity(),
                         sortDescriptors: [NSSortDescriptor(keyPath: \Category.createdAt, ascending: false)],
                         predicate: prd)
        
        let count = req.wrappedValue.count
        switch count {
        case 0:
            cat = Category(context: self.viewContext)
//            cat = NSEntityDescription.insertNewObject(forEntityName: Category.entity().name!,
//                                                      into: self.viewContext) as? Category
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
            cat = req.wrappedValue.first
        case 2...:
            J1Logger.shared.error("kind=\(kind) count=\(count)")
            cat = req.wrappedValue.first
        default:
            J1Logger.shared.error("kind=\(kind) count=\(count)")
            cat = req.wrappedValue.first
        }
        
        return cat
    }
    
    private func setup() {
        Self.CategoryAll   = self.singleton(kind: .all,   name: "All")
        Self.CategoryTrash = self.singleton(kind: .trash, name: "Trash")
    }
}
