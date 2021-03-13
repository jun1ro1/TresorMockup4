//
//  SettingsViewController.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/10/08.
//  Copyright (C) 2020 OKU Junichirou. All rights reserved.
//
// https://joyplot.com/documents/2016/11/03/icloud-document-container/
// https://qiita.com/KakeruFukuda/items/5c79a6d4c4b4e1458487
// https://joyplot.com/documents/2016/11/04/swift-icloud-textfile/
// https://qiita.com/Necorin/items/cb8aae50356c233c20b0
// https://qiita.com/ShingoFukuyama/items/e85d34360f3f951ca612
// https://theswiftdev.com/how-to-use-icloud-drive-documents/
// https://stackoverflow.com/questions/33886846/best-way-to-use-icloud-documents-storage

import UIKit
import CoreData
import UniformTypeIdentifiers

import CSV
import SwiftyBeaver

class SettingsViewController: UITableViewController, UIDocumentPickerDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet var cellImport: UITableViewCell!
    @IBOutlet var cellExport: UITableViewCell!
    @IBOutlet var cellDataClear: UITableViewCell!
    
    private var cacheName: String? = nil
    private var managedObjectContext: NSManagedObjectContext? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cacheName = String(describing: self)
        self.managedObjectContext = CoreDataManager.shared.persistentContainer.viewContext
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        switch cell {
        case cellImport:            // https://stackoverflow.com/questions/62653008/initialization-of-uidocumentpickerviewcontroller-in-ios-14
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText], asCopy: true)
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            self.present(picker, animated: true) {
                if let indexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        case cellExport:
            let folder = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
            let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)!
                .appendingPathComponent(folder)
                .appendingPathComponent("test").appendingPathExtension("csv")
            SwiftyBeaver.self.info("url=\(url)")
            
            if !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
                try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            self.present(picker, animated: true) {
                if let indexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        case cellDataClear:
            AuthenticationManger.shared.authenticate(self) { auth in
                if auth {
                    self.clearAllData()
                }
                if let indexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        default:
            SwiftyBeaver.self.error("Unknown cell at \(indexPath)")
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        SwiftyBeaver.self.info("URL = \(String(describing: urls.first))")
        if controller.documentPickerMode == .import {
            self.importFromCSV(url: urls.first!)
        }
        else {
            self.exportToCSV(url: urls.first!)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        SwiftyBeaver.self.info("cancelled")
    }
    
    fileprivate func importFromCSV(url: URL) {
        let csv: CSVReader
        do {
            csv = try CSVReader(stream: InputStream(url: url)!)
        } catch let error {
            SwiftyBeaver.error("CSVReader error=\(error)")
            return
        }
        
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: self.cacheName!)
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        var entities: [[String: String]] = []
        var header: [String]? = nil
        while let row = csv.next() {
            guard header != nil else {
                header = row
                print("\(header!)")
                continue
            }
            let properties: [String: String] = Dictionary(uniqueKeysWithValues: zip(header!, row))
            entities.append(properties)
        }
        
        let names = Site.entity().properties.map { $0.name }
        let highPriorityNames = ["title", "url", "userid", "passwordCurrent"]
        
        guard Set(header!).isSubset(of: names) else {
            SwiftyBeaver.self.error("Wrong header=\(header!)")
            return
        }
        
        guard Set(highPriorityNames).isSubset(of: header!) else {
            SwiftyBeaver.self.error("Wrong header=\(header!)")
            return
        }
        
        let UUID = "uuid"
        let URL  = "url"
        entities.forEach { properties in
            var newItem: Site? = nil
            
            if let id = properties[UUID], id != "" {
                let predicate = NSPredicate(format: "\(UUID) == %@", id)
                self.fetchedResultsController.fetchRequest.predicate = predicate
                SwiftyBeaver.self.debug("context fetch request predicate = \(predicate)")
                
                NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: self.cacheName!)
                do {
                    try self.fetchedResultsController.performFetch()
                } catch let error {
                    SwiftyBeaver.self.error("performFetch error=\(error) predicate=\(predicate)")
                }
                let sites = self.fetchedResultsController.fetchedObjects
                if sites == nil || sites!.count == 0 {
                    let context = CoreDataManager.shared.persistentContainer.viewContext
                    newItem = Site(context: context)
                    newItem!.readString(from: properties)
                }
                else if sites!.count == 1 {
                    SwiftyBeaver.self.error("already exists: \(sites!)")
                }
                else if sites!.count > 1 {
                    SwiftyBeaver.self.error("consistency error: \(sites!)")
                }
            }
            else if let url = properties[URL], url != "" {
                let predicate = NSPredicate(format: "\(URL) == %@", url)
                self.fetchedResultsController.fetchRequest.predicate = predicate
                SwiftyBeaver.self.debug("context fetch request predicate = \(predicate)")
                
                NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: self.cacheName!)
                do {
                    try self.fetchedResultsController.performFetch()
                } catch let error {
                    SwiftyBeaver.self.error("performFetch error=\(error) predicate=\(predicate)")
                }
                let sites = self.fetchedResultsController.fetchedObjects
                if sites == nil || sites!.count == 0 {
                    let context = CoreDataManager.shared.persistentContainer.viewContext
                    newItem = Site(context: context)
                    newItem!.readString(from: properties)
                }
                else if sites!.count == 1 {
                    SwiftyBeaver.self.error("already exists: \(sites!)")
                }
                else if sites!.count > 1 {
                    SwiftyBeaver.self.error("consistency error: \(sites!)")
                }
            }
            else {
                SwiftyBeaver.self.error("uuid and url are nil: \(properties)")
                return
            }
            
            if properties.keys.contains("passwordCurrent") {
                let password = PasswordManager.shared.newObject(for: newItem!)
                password.password = properties["passwordCurrent"]  // ***ENCRYPT***
                PasswordManager.shared.select(password: password, for: newItem!)
            }
        }
        
        let context = self.fetchedResultsController.managedObjectContext
        context.performAndWait {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                SwiftyBeaver.self.error("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    
    fileprivate func exportToCSV(url: URL) {
        var names         = Site.entity().properties.map { $0.name }
        var highPriorityNames = ["title", "url", "userid", "passwordCurrent"]
        if !Set(highPriorityNames).isSubset(of: names) {
            SwiftyBeaver.error("\(highPriorityNames) is not a subset of \(names)")
            highPriorityNames = []
        }
        let lowPriorityNames  = Set(names).subtracting(highPriorityNames)
        names = highPriorityNames + lowPriorityNames
        SwiftyBeaver.debug("names=\(names)")
        
        SwiftyBeaver.self.info("url=\(url)")
        
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: self.cacheName!)
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        let sites: [Site] = self.fetchedResultsController.fetchedObjects ?? []
        
        guard let stream = OutputStream(url: url, append: false) else {
            SwiftyBeaver.error("OutputStream error url=\(url)")
            return
        }
        
        let csv: CSVWriter
        do {
            csv = try CSVWriter(stream: stream)
        } catch(let error) {
            SwiftyBeaver.error("CSVWriter fails=\(error)")
            return
        }
        
        do {
            try csv.write(row: names)
        } catch let error {
            SwiftyBeaver.error("csv.write error=\(error) names=\(names)")
        }
        
        let dateFormatter = ISO8601DateFormatter()
        sites.forEach { site in
            csv.beginNewRow()
            names.forEach { name in
                let val: Any = site.value(forKey: name) as Any
                let str: String
                switch val {
                case nil:             str = ""
                case let v as Bool:   str = v.description
                case let v as Int:    str = String(v)
                case let v as Date:   str = dateFormatter.string(from: v)
                case let v as String: str = v
                default: str = ""
                }
                
                do {
                    try csv.write(field: str)
                } catch let error {
                    SwiftyBeaver.error("csv.write error=\(error) value=\(str)")
                }
            }
        }
        csv.stream.close()
    }
    
    fileprivate func clearAllData() {
        let handler: (UIAlertAction)->Void = { _ in
            // https://stackoverflow.com/questions/24658641/ios-delete-all-core-data-swift
            let context = CoreDataManager.shared.persistentContainer.viewContext
            [Password.entity().name!, Site.entity().name!].forEach { name in
                let fetchRequest  = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                context.performAndWait {
                    do {
                        try context.execute(deleteRequest)
                    } catch let error{
                        SwiftyBeaver.self.error("NSBatchDeleteRequest name=\(name) error=\(error)")
                        return
                    }
                }
                context.performAndWait {
                    do {
                        try context.save()
                    } catch let error {
                        SwiftyBeaver.self.error("save error name=\(name) error=\(error)")
                        return
                    }
                }
            }
        }
        let alert = UIAlertController(title: "Clear all data", message: "Are you sure to clear all data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: handler))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }
    
    var fetchedResultsController: NSFetchedResultsController<Site> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<Site> = Site.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true, selector:#selector(NSString.localizedStandardCompare))
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.managedObjectContext!,
            sectionNameKeyPath: nil,
            cacheName: self.cacheName!)
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<Site>? = nil
}
