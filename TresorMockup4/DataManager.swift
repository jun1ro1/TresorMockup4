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

protocol PrioritizedNameManagedObject {
    static var sortNames: [String] { get }
}
protocol PublishableManagedObject {
    static func publisher(sortNames: [String], predicate: NSPredicate?)
    -> AnyPublisher<[String: String]?, Error>
}

class ExportEngine {
    private var entity:  PublishableManagedObject.Type
    private var fileURL: URL
    private var stream:  OutputStream
    private var writer:  CSVWriter? = nil
    private var error:   Error?     = nil

    private var temporaryURL: URL {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        return tempURL
    }

    init(entity: PublishableManagedObject.Type, url: URL) {
        self.entity =  entity
        self.fileURL = url
            .appendingPathComponent(String(describing: self.entity), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)

        self.stream = OutputStream(url: self.fileURL, append: false)!
        do {
            self.writer = try CSVWriter(stream: stream)
        } catch let error {
            self.error = error
        }
    }

    var url: URL {
        return self.fileURL
    }

    func tablePublisher(publisher: AnyPublisher<[String: String]?, Error>,
                              headerPublisher: AnyPublisher<[String], Error>)
    -> AnyPublisher<[String], Error> {
        return headerPublisher.combineLatest(publisher.prepend(nil))
            .map { (keys, dict) -> [String] in
                dict == nil ? keys : keys.map { dict![$0] ?? "" }
            }.eraseToAnyPublisher()
    }

    func tableHeaderPublisher(publisher: AnyPublisher<[String: String]?, Error>,
                              sortNames: [String] = [])
    -> AnyPublisher<[String], Error> {
        return publisher.first().map {
            guard let dict = $0 else { return [] }
            var names    = Array(dict.keys)
            var snames   = sortNames
            let unknowns = Set(snames).subtracting(Set(names))
            if unknowns != [] {
                J1Logger.shared.error("\(sortNames) have unknown names \(unknowns)")
                snames.removeAll { unknowns.contains($0) }
            }
            let onames  = Set(names).subtracting(snames)
            names = snames + onames.sorted()
            return names
        }.eraseToAnyPublisher()
    }

    func backupPublisher() -> AnyPublisher<[String], Error> {
        let sortNames = (self.entity as! PrioritizedNameManagedObject.Type).sortNames
        let publisher = self.entity.publisher(sortNames: sortNames, predicate: nil)
        let header    = self.tableHeaderPublisher(publisher: publisher, sortNames: sortNames)
        return self.tablePublisher(publisher: publisher, headerPublisher: header)
    }

    var publisher: AnyPublisher<[String], Error> {
        return self.backupPublisher()
            .tryMap {
                guard self.error == nil else {
                    throw self.error!
                }
                do {
                    try self.writer?.write(row: $0)
                } catch let error {
                    self.error = error
                    throw self.error!
                }
                return $0
            }.eraseToAnyPublisher()
    }

    func close() {
        self.writer?.stream.close()
    }
}

class DataManager {
    static let shared = DataManager()
    
    private var temporaryURL: URL {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        return tempURL
    }

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

    func backup() -> AnyPublisher<URL, Error> {
         let tempURL = self.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        let engineCategory = ExportEngine(entity: Category.self, url: tempURL)
        let engineSite     = ExportEngine(entity: Site.self,     url: tempURL)
        let enginePassword = ExportEngine(entity: Password.self, url: tempURL)

        let engines: [ExportEngine] = [engineCategory, engineSite, enginePassword]
        let publishers = engines.map { $0.publisher }
        let cancellable = publishers.dropFirst().reduce(publishers[0]) {
            $0.append($1).eraseToAnyPublisher()
        }

        return Deferred {
            Future<URL, Error> { promise in
                _ = cancellable.sink { completion in
                    engines.forEach { $0.close() }

                    switch completion {
                    case .finished:
                        var error: Error? = nil
                        let urls =  [engineCategory.url, engineSite.url, enginePassword.url]
                        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
                        let timestr = self.timeString
                        let urlZip = urls[0].deletingLastPathComponent().appendingPathComponent("\(name)-\(timestr).zip")
                        do {
                            try Zip.zipFiles(paths: urls, zipFilePath: urlZip, password: nil) { _ in
                            }
                        } catch let err {
                            error = err
                            J1Logger.shared.error("Zip.zipFiles = \(error!)")
                        }

                        urls.forEach { (url) in
                            do {
                                try FileManager.default.removeItem(at: url)
                            } catch let error {
                                J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
                            }
                        }
                        if error == nil {
                            promise(.success(urlZip))
                        } else {
                            promise(.failure(error!))
                        }

                    case .failure(let error):
                        J1Logger.shared.error("error = \(error)")
                        promise(.failure(error))
                    }
                } receiveValue: { arg in
                    print(arg)
                }

            }
        }.eraseToAnyPublisher()
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
