//
//  Restorer.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/03/18.
//

import Foundation
import CoreData
import Combine

class Restorer<T: NSManagedObject> {
    var cancellable: AnyCancellable?
    var keys: [String]
    var array: [(NSManagedObject, [String: String])]
    var context: NSManagedObjectContext
    
    init(searchingKeys keys: [String], context: NSManagedObjectContext) {
        self.keys  = keys
        self.array = []
        self.context = context
    }
    
    func load<P: Publisher>(from publisher: P)  where P.Output == Dictionary<String, String> {
        self.cancellable = publisher.sink { completion in
            switch completion {
            case .finished:
                print("load finished")
            case .failure(let error):
                print("error = \(error)")
            }
        } receiveValue: {  [weak self] dict in
            guard let self = self else { return }
            
            var keys = self.keys
            var obj: T? = nil
            while obj == nil && keys.count > 0 {
                let key = keys.removeFirst()
                guard let valstr = dict[key] else {
                    J1Logger.shared.debug("\(key) value is nil in \(dict)")
                    continue
                }
                
                let request: NSFetchRequest<T> = NSFetchRequest(entityName: T.entity().name!)
                
                var predicate: NSPredicate?
                switch T.entity().attributesByName[key]?.attributeType {
                case .UUIDAttributeType:
                    predicate = NSPredicate(format: "%K == %@", "uuid", UUID(uuidString: valstr)! as CVarArg)
                case .stringAttributeType:
                    predicate = NSPredicate(format: "%K == %@", key, valstr)
                default:
                    predicate = nil
                }
                guard predicate != nil else {
                    J1Logger.shared.error("Unknown attribute type")
                    continue
                }
                
                request.predicate = predicate
                request.sortDescriptors = nil
                
                var items: [T]
                do {
                    items = try self.context.fetch(request)
                } catch let error {
                    J1Logger.shared.error("fetch \(request) error = \(error)")
                    return
                }
                guard items.count > 0 else {
                    J1Logger.shared.debug("fetch count = 0 \(request)")
                    continue
                }
                obj = items.first
            }
            
            if obj == nil {
                obj = T.init(context: self.context)
            }
            obj!.setPrimitive(from: dict)
            self.array.append((obj!, dict))
        } // receiveValue
    }
    
    func link() {
        let links = T.entity().relationshipsByName
        
        let publisher = self.array.publisher
        self.cancellable = publisher.sink { completion in
            switch completion {
            case .finished:
                print("link finished")
            case .failure(let error):
                print("error = \(error)")
            }
        } receiveValue: {  [weak self] parm in
            guard self != nil else { return }
            let (obj, dict) = parm
            
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
                    items = try self!.context.fetch(request)
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
                
                print("\(String(describing: T.entity().name)) : \(name) -> \(String(describing: item.value(forKey: "uuid")))")
                obj.setPrimitiveValue(item, forKey: name)
            }
        }
    }
    
    func cancel() {
        self.cancellable?.cancel()
    }
}

