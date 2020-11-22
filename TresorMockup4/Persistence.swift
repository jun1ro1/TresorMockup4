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
        
        let titles = [
            "antipreparedness",
            "decaphyllous",
            "rightle",
            "scrunt",
            "transpanamic",
            "typhomalaria",
            "sapiential",
            "uteroventral",
            "uncinch",
            "isoantibody",
            "asaraceae",
            "argean",
            "arterioverter",
            "titianic",
            "entoptoscope",
            "indistinguished",
            "sundriesman",
            "comprisable",
            "kyu",
            "skeezix",
            "demitone",
            "intershade",
            "sitfast",
            "pashm",
            "unwhimsical",
            "transliterate",
            "suspirious",
            "reinduce",
            "melanoderma",
            "surround",
            "ganging",
            "turnsheet",
            "slugger",
            "tetramethylammonium",
            "rousement",
            "morphophyly",
            "tauromachic",
            "introconvertibility",

        ]
        
        let urls = [
            "https://auth.antipreparedness.ad.am",
            "https://www2.decaphyllous.co.gov",
            "https://rightle.ac.wf",
            "https://www8.scrunt.gr.ad",
            "https://www2.transpanamic.ne.ar",
            "https://www9.typhomalaria.lg.az",
            "https://sapiential.lg.am",
            "https://www3.uteroventral.or.mil",
            "https://www4.uncinch.or.je",
            "https://auth.isoantibody.ed.mo",
            "https://www4.asaraceae.or.tw",
            "https://www9.argean.ne.my",
            "https://www3.arterioverter.lg.gn",
            "https://auth.titianic.lg.pw",
            "https://www3.entoptoscope.gr.sv",
            "https://www3.indistinguished.or.lc",
            "https://auth.sundriesman.ne.info",
            "https://www0.comprisable.go.eu",
            "https://auth.kyu.bl",
            "https://www0.skeezix.gr.lk",
            "https://www8.demitone.ac.cg",
            "https://www5.intershade.ed.lt",
            "https://www5.sitfast.or.ye",
            "https://www6.pashm.co.in",
            "https://www5.unwhimsical.me",
            "https://www1.transliterate.ed.sj",
            "https://www4.suspirious.bl",
            "https://www.reinduce.ac.gi",
            "https://melanoderma.co.mil",
            "https://www4.surround.co.np",
            "https://www9.ganging.go.na",
            "https://www7.turnsheet.go.th",
            "https://www.slugger.ed.vc",
            "https://www5.tetramethylammonium.ad.sh",
            "https://www8.rousement.or.yt",
            "https://morphophyly.lg.cw",
            "https://tauromachic.ed.is",
            "https://www6.introconvertibility.ed.to",
        ]
        
        assert(titles.count == urls.count)
        var sites: [Dictionary<String, String>] = []
        for i in 0..<titles.count {
            sites.append( [ "title": titles[i],
                            "titleSort": titles[i],
                            "url":   urls[i],
                            "user":  "user\(String(i))",
                            "password": "pass\(String(i))"
            ])
        }
        sites.forEach {
            let _ = Site(from: $0, context: viewContext)
        }
        
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
        container = NSPersistentCloudKitContainer(name: "TresorMockup4")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
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
    }
}
