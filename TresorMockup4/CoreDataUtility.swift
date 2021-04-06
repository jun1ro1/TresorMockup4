//
//  BackupRestore.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/04/06.
//

import Foundation
import CoreData
import Combine

import Zip

class CoreDataUtility {
    static let shared = CoreDataUtility()
    
    func deleteAll() {
        Password.deleteAll()
        Site.deleteAll()
        Category.deleteAll()
        
        let viewContext = PersistenceController.shared.container.viewContext
        viewContext.refreshAllObjects()
    }
    
    func backup() -> URL {
        let now       = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.formatOptions = [.withFullDate, .withFullTime, .withSpaceBetweenDateAndTime]
        formatter.formatOptions.remove(
            [.withDashSeparatorInDate, .withColonSeparatorInTime,
             .withColonSeparatorInTimeZone, .withSpaceBetweenDateAndTime,
             .withTimeZone])
        let timestr = formatter.string(from: now)
        
        let urlCategory = Category.backup()
        let urlSite     = Site.backup()
        let urlPassword = Password.backup()
        J1Logger.shared.debug("urlCategory = \(String(describing: urlCategory))")
        J1Logger.shared.debug("urlSite     = \(String(describing: urlSite))")
        J1Logger.shared.debug("urlPassword = \(String(describing: urlPassword))")
        
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let urlZip = urlSite?.deletingLastPathComponent().appendingPathComponent("\(name)-\(timestr).zip")
        
        let urls =  [urlCategory!, urlSite!, urlPassword!]
        do {
            try Zip.zipFiles(paths: urls, zipFilePath: urlZip!, password: nil) { _ in
            }
        } catch let error {
            J1Logger.shared.error("Zip.zipFiles = \(error)")
        }
        
        urls.forEach { (url) in
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error {
                J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
            }
        }
        return urlZip!
    }
    
    func restore(url: URL) {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        J1Logger.shared.debug("url = \(String(describing: url))")
        
        let tempURL =
            FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent( (0...9).shuffled().map { String($0) }.joined(), isDirectory: true)
        J1Logger.shared.debug("tempURL = \(tempURL)")
        
        do {
            try Zip.unzipFile(url, destination: tempURL, overwrite: true, password: nil)
        } catch let error {
            J1Logger.shared.error("Zip.unzipFile = \(error)")
        }
        
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            var publisher: CSVPublisher
            
            let csvSite = tempURL.appendingPathComponent("Site.csv", isDirectory: false)
            publisher = CSVPublisher(url: csvSite)
            let loaderSite = Restorer<Site>(searchingKeys: ["uuid", "url", "title"], context: context)
            loaderSite.load(from: publisher.subject)
            publisher.send()
            
            let csvCategory = tempURL.appendingPathComponent("Category.csv", isDirectory: false)
            publisher = CSVPublisher(url: csvCategory)
            let loaderCategory = Restorer<Category>(searchingKeys: ["uuid", "name"], context: context)
            loaderCategory.load(from: publisher.subject)
            publisher.send()
            
            let csvPassword = tempURL.appendingPathComponent("Password.csv", isDirectory: false)
            publisher = CSVPublisher(url: csvCategory)
            let loaderPassword = Restorer<Password>(searchingKeys: ["uuid", "password"], context: context)
            loaderPassword.load(from: publisher.subject)
            publisher.send()
            
            loaderSite.link()
            loaderCategory.link()
            loaderPassword.link()
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    J1Logger.shared.error("Unresolved error \(nsError), \(nsError.userInfo)")
                }
                J1Logger.shared.debug("save context")
            }
            context.reset()
            
            [csvSite, csvCategory, csvPassword, tempURL].forEach { (url) in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch let error {
                    J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
                }
            }
        }
    }
}
