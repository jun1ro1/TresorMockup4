//
//  Persistence.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
         
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        self.container = NSPersistentCloudKitContainer(name: "TresorMockup4")
        let debugging = false
        #if DEBUG
//        debugging = true
        #endif
        
        if inMemory || debugging {
            self.container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        self.container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            #if DEBUG
            let url = storeDescription.url?.absoluteString ?? "nil"
            J1Logger.shared.debug("persistent store URL = \(url)")
            #endif
            
            
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        // https://qiita.com/tasuwo/items/abe90e8302f261f11845
        // https://qiita.com/MaShunzhe/items/5cc294324f0ecc54c264
        // https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud
        self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
