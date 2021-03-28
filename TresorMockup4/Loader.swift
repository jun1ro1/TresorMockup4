//
//  Restorer.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/03/18.
//

import Foundation
import CoreData
import Combine

class Loader<T: NSManagedObject> {
    let viewContext = PersistenceController.shared.container.viewContext
    var cancellable: AnyCancellable?
    var url: URL
    var keys: [String]
    
    init(url: URL, searchingKeys keys: [String]) {
        self.url  = url
        self.keys = keys
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
            
            let viewContext = PersistenceController.shared.container.viewContext
            var keys = self.keys
            var obj: T? = nil
            while obj == nil && keys.count > 0 {
                let key = keys.removeFirst()
                guard let val = dict[key] else { continue }
                
                let request: NSFetchRequest<T> = NSFetchRequest(entityName: T.entity().name!)
                request.predicate = NSPredicate(format: "%K == %@", key, val)
                request.sortDescriptors = nil
               
                var items: [T]
                do {
                    items = try viewContext.fetch(request)
                } catch let error {
                    J1Logger.shared.error("fetch \(request) error = \(error)")
                    return
                }
                guard items.count > 0 else {
                    J1Logger.shared.error("fetch count = 0 \(request)")
                    continue
                }
                obj = items.first
            }
            
            if obj == nil {
                obj = T.init(context: self.viewContext)
            }
            obj!.set(from: dict)
        }
        
        publisher.start()
    }
    
    func link() {
        let links = T.entity().relationshipsByName
        
        let publisher = CSVPublisher(url: self.url)
        self.cancellable = publisher.subject.sink { completion in
            switch completion {
            case .finished:
                print("link finished")
            case .failure(let error):
                print("error = \(error)")
            }
        } receiveValue: {  [weak self] dict in
            guard let _ = self else { return }
            
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
                
                let viewContext = PersistenceController.shared.container.viewContext
                
                // https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9
                let uuid = UUID(uuidString: uuidstr)
                let request: NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: dest.name!)
                request.predicate = NSPredicate(format: "%K == %@", "uuid", uuid! as CVarArg)
                request.sortDescriptors = nil
                
                var items: [Any] = []
                do {
                    items = try viewContext.fetch(request)
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
                
                print("\(String(describing: T.entity().name)) : \(name) -> \(item)")
            }
        }
        
        publisher.start()
    }
    
    func cancel() {
        self.cancellable?.cancel()
    }
}

