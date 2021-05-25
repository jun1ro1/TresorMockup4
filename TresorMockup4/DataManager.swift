//
//  BackupRestore.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/04/06.
//

import Foundation
import CoreData
import Combine

import CSV
import Zip

class DataManager {
    static let shared = DataManager()
    
    func deleteAll() {
        Password.deleteAll()
        Site.deleteAll()
        Category.deleteAll()
        
        let viewContext = PersistenceController.shared.container.viewContext
        viewContext.refreshAllObjects()
    }
    
    private var timeString: String {
        let now       = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.formatOptions = [.withFullDate, .withFullTime, .withSpaceBetweenDateAndTime]
        formatter.formatOptions.remove(
            [.withDashSeparatorInDate, .withColonSeparatorInTime,
             .withColonSeparatorInTimeZone, .withSpaceBetweenDateAndTime,
             .withTimeZone])
        return formatter.string(from: now)
    }
    
    private var temporaryURL: URL {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        return tempURL
    }

    
    func backup() -> URL? {
        let tempURL = self.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        let writerPublisher = {
            [$0].publisher.tryMap { (schema) -> (CSVWriter, URL) in
                let fileURL = tempURL
                    .appendingPathComponent(String(describing: schema), isDirectory: false)
                    .appendingPathExtension(for: .commaSeparatedText)
                let stream = OutputStream(url: fileURL, append: false)!
                let writer = try CSVWriter(stream: stream)
                return (writer, fileURL)
            }.eraseToAnyPublisher()
        }

        let publisherCategory = Category.backupPublisher().combineLatest(writerPublisher(Category.self))
            .tryMap { (values: [String], arg2) -> ([String], CSVWriter, URL) in
                let csv = arg2.0
                let url = arg2.1
                try csv.write(row: values)
                return (values, csv, url)
            }.eraseToAnyPublisher()
        let publisherSite = Site.backupPublisher().combineLatest(writerPublisher(Site.self))
            .tryMap { (values: [String], arg2) -> ([String], CSVWriter, URL) in
                let csv = arg2.0
                let url = arg2.1
                try csv.write(row: values)
                return (values, csv, url)
            }.eraseToAnyPublisher()
        let publisherPassword = Password.backupPublisher().combineLatest(writerPublisher(Password.self))
            .tryMap { (values: [String], arg2) -> ([String], CSVWriter, URL) in
                let csv = arg2.0
                let url = arg2.1
                try csv.write(row: values)
                return (values, csv, url)
            }.eraseToAnyPublisher()

        let cancellable = publisherCategory
            .flatMap { _ in publisherSite     }
            .flatMap { _ in publisherPassword }

        _ = cancellable.sink { completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                J1Logger.shared.error("error = \(error)")

            }
        } receiveValue: { arg in
            print(arg)
        }

        return tempURL


//            .sink { completion -> URL? in
//                csv.stream.close()
//                switch completion {
//                case .finished:
//                    J1Logger.shared.debug("finished")
//                    return fileURL
//                case .failure(let error):
//                    J1Logger.shared.error("error = \(error)")
//                    return nil
//                }
//            } receiveValue: { values in
//                do {
//                    try csv.write(row: values)
//                } catch let error {
//                    J1Logger.shared.error("error = \(error)")
//                }
//            }
//        }
//        guard !urls.isEmpty else {
//            return nil
//        }
//
//        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
//        let timestr = self.timeString
//        let urlZip = urls[0].deletingLastPathComponent().appendingPathComponent("\(name)-\(timestr).zip")
//
//        do {
//            try Zip.zipFiles(paths: urls, zipFilePath: urlZip, password: nil) { _ in
//            }
//        } catch let error {
//            J1Logger.shared.error("Zip.zipFiles = \(error)")
//        }
//
//        urls.forEach { (url) in
//            do {
//                try FileManager.default.removeItem(at: url)
//            } catch let error {
//                J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
//            }
//        }
//        return urlZip

    }
    
    func restore(url: URL) {
        let tempURL = self.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")
        
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
            publisher = CSVPublisher(url: csvPassword)
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
    
    func export(cryptor: CryptorUI) -> URL {
        let tempURL = self.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")
        
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let timestr = self.timeString
        let fileURL = tempURL
            .appendingPathComponent("\(name)-\(timestr)", isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)
        
        Site.export(url: fileURL, cryptor: cryptor)
        J1Logger.shared.debug("fileURL = \(String(describing: fileURL))")
        
        return fileURL
    }
    
    func `import`(url: URL, cryptor: CryptorUI) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            let publisher = CSVPublisher(url: url)
            let subject:  AnyPublisher<Dictionary<String, String>, Error>
                = publisher.subject.tryMap {
                    var dict = $0
                    if let plain = dict["password"], !plain.isEmpty {
                        let proxy = PasswordProxy()
                        proxy.plain = plain
                        try proxy.endecrypt(cryptor: cryptor)
                        dict["password"] = proxy.cipher
//                        dict["passwordHash"] = proxy.passwordHash
                    }
                    return dict
                }.eraseToAnyPublisher()
            let loaderSite = Restorer<Site>(searchingKeys: ["url", "title"], context: context)
            loaderSite.load(from: subject)
            publisher.send()

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
            DispatchQueue.main.async {
                cryptor.close(keep: false)
            }
        }
    }
}
