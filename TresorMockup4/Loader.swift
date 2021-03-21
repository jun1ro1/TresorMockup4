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
                print("finished")
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
                
                guard let items = try? viewContext.fetch(request) else { return }
                guard items.count > 0 else { continue }
                obj = items.first
            }
            
            if obj == nil {
                obj = T.init(context: self.viewContext)
            }
            obj?.set(from: dict)
        }
        
        publisher.start()
    }
    
    func cancel() {
        self.cancellable?.cancel()
    }
}

