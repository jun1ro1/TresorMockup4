//
//  ImportEngine.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/06/12.
//

import Foundation
import CoreData
import Combine

import CSV
import Zip

final class ImportEngine {
    var entity:     NSManagedObject.Type
    var keys:       [String]
    var context:    NSManagedObjectContext
    var collection: [([String : String], NSManagedObject)] = []
    var cancelled:  Bool? = false

    init(entity: NSManagedObject.Type, searchingKeys keys: [String], context: NSManagedObjectContext) {
        self.entity  = entity
        self.keys    = keys
        self.context = context
    }

    deinit {
        J1Logger.shared.debug("deinit")
    }

    static var temporaryURL: URL {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        return tempURL
    }

    func managedObjectPublisher(publisher: AnyPublisher<[String: String], Error>)
    -> AnyPublisher<([String: String], NSManagedObject), Error> {
        let entity     = self.entity
        let entityName = entity.entity().name ?? "nil-name"
        let context    = self.context

        return publisher.tryMap { [weak self] dict in
            var keys: [String]        = self?.keys ?? []
            var obj: NSManagedObject? = nil
            while obj == nil && keys.count > 0 {
                let key = keys.removeFirst()
                guard let valstr = dict[key] else {
                    J1Logger.shared.debug("entity = \(entityName) \(key) value is nil in \(dict)")
                    continue
                }
                let request: NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                var predicate: NSPredicate?
                switch entity.entity().attributesByName[key]?.attributeType {
                case .UUIDAttributeType:
                    predicate = NSPredicate(format: "%K == %@", "uuid", UUID(uuidString: valstr)! as CVarArg)
                case .stringAttributeType:
                    predicate = NSPredicate(format: "%K == %@", key, valstr)
                default:
                    predicate = nil
                }
                guard predicate != nil else {
                    J1Logger.shared.error("entity = \(entityName) Unknown attribute type")
                    continue
                }
                request.predicate = predicate
                request.sortDescriptors = nil

                var items: [NSManagedObject]
                do {
                    items = try context.fetch(request) as! [NSManagedObject]
                } catch let error {
                    J1Logger.shared.error("entity = \(entityName) fetch \(request) error = \(error)")
                    throw error
                }
                guard items.count > 0 else {
                    J1Logger.shared.debug("entity = \(entityName) fetch count = 0 \(request)")
                    continue
                }
                obj = items.first
            }

            if obj == nil {
                obj = entity.init(context: context)
            }
            return (dict, obj!)
        }.eraseToAnyPublisher()
    }

    // https://qiita.com/toya108/items/5558c26817f6d2b67853
    func restorePublisher(publisher: AnyPublisher<([String: String], NSManagedObject), Error>)
    -> AnyPublisher<([String: String], NSManagedObject), Error> {
        let pub = publisher.map { [weak self] (dict, obj) -> ([String: String], NSManagedObject) in
            if self?.cancelled != true {
                obj.setPrimitive(from: dict)
                self?.collection.append((dict, obj))
            }
            return (dict, obj)
        }.eraseToAnyPublisher()
        return pub
    }


    func linkPublisher()
    -> AnyPublisher<([String: String], NSManagedObject), Error> {
        let links      = self.entity.entity().relationshipsByName
        let entityName = self.entity.entity().name ?? "nil-name"
        J1Logger.shared.debug("Entity = \(entityName)")

        let publisher = self.collection.publisher
        let context   = self.context
        return publisher.tryMap { [weak self] (dict, obj) in
            links.forEach { link in
                let name = link.key
                guard !link.value.isToMany else { return }

                guard let dest = link.value.destinationEntity else {
                    J1Logger.shared.error("name = \(name), \(link.value) has no destinationEntry")
                    return
                }
                guard let uuidstr = dict[name], !uuidstr.isEmpty else {
                    J1Logger.shared.debug("name = \(name) no link")
                    return
                }

                // https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9
                let uuid = UUID(uuidString: uuidstr)
                let request: NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: dest.name!)
                request.predicate = NSPredicate(format: "%K == %@", "uuid", uuid! as CVarArg)
                request.sortDescriptors = nil

                var items: [Any] = []
                do {
                    items = try context.fetch(request)
                } catch let error {
                    J1Logger.shared.error("name = \(name) fetch = \(error)")
                }
                guard items.count > 0 else {
                    J1Logger.shared.error("name = \(name) dest = \(dest.name!) \(String(describing: request.predicate)) not found")
                    return
                }
                guard let item = items.first as? NSManagedObject else {
                    J1Logger.shared.error("name = \(name) \(items) are not NSManagedObject")
                    return
                }

                J1Logger.shared.debug("\(entityName) : \(name) -> \(String(describing: item.value(forKey: "uuid")))")
                if let oldval = obj.primitiveValue(forKey: name) {
                    J1Logger.shared.debug("\(entityName) : \(name) is \(String(describing: oldval))")
                } else {
                    if self?.cancelled != true {
                        obj.setPrimitiveValue(item, forKey: name)
                    }
                }
            }
            return (dict, obj)
        }.eraseToAnyPublisher()
    }
}
