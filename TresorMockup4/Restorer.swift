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
    let viewContext = PersistenceController.shared.container.viewContext
    var cancellable: AnyCancellable?
    
    func perform(url: URL) {
        let publisher = CSVPublisher(url: url)
        self.cancellable = publisher.subject.sink { completion in
            switch completion {
            case .finished:
                print("finished")
            case .failure(let error):
                print("error = \(error)")
            }
        } receiveValue: {  [weak self] dict in
            guard let self = self else { return }
//            print(dict)
            if let uuid = dict["uuid"] {
                var obj = (try? T.find(predicate: NSPredicate(format: "%K == %@", "uuid", uuid)))?.first
                if obj == nil {
                    obj = T.init(context: self.viewContext)
                }
                obj?.set(from: dict)
                print(obj?.objectID.uriRepresentation().absoluteURL ?? "nil")
            }
        }
        
        publisher.start()
    }
    
    func cancel() {
        self.cancellable?.cancel()
    }
}

