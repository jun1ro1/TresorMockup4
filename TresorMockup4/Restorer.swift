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
    var url: URL
    var keys: [String]
    var array: [(NSManagedObject, [String: String])]
    var viewContext: NSManagedObjectContext
    
    init(url: URL, searchingKeys keys: [String], context: NSManagedObjectContext) {
        self.url   = url
        self.keys  = keys
        self.array = []
        self.viewContext = context
    }
    
    func load() {
        let publisher = CSVPublisher(url: self.url)
        self.cancellable = publisher.subject.sink { completion in
            switch completion {
            case .finished:
                print("load finished")
            case .failure(let error):
                print("error = \(error)")
            }
        } receiveValue: {  [weak self] dict in
            guard let self = self else { return }
            
            let viewContext = self.viewContext
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
                    J1Logger.shared.debug("Unknown attribute type")
                    continue
                }
                
                request.predicate = predicate
                request.sortDescriptors = nil
               
                var items: [T]
                do {
                    items = try viewContext.fetch(request)
                } catch let error {
                    J1Logger.shared.debug("fetch \(request) error = \(error)")
                    return
                }
                guard items.count > 0 else {
                    J1Logger.shared.debug("fetch count = 0 \(request)")
                    continue
                }
                obj = items.first
            }
            
            if obj == nil {
                obj = T.init(context: self.viewContext)
            }
            obj!.setPrimitive(from: dict)
            self.array.append((obj!, dict))
        }
        
        publisher.start()
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
                
                let viewContext = self?.viewContext
                
                // https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9
                let uuid = UUID(uuidString: uuidstr)
                let request: NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: dest.name!)
                request.predicate = NSPredicate(format: "%K == %@", "uuid", uuid! as CVarArg)
                request.sortDescriptors = nil
                
                var items: [Any] = []
                do {
                    items = try viewContext!.fetch(request)
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

