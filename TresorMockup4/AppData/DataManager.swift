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

enum DataManagerError: Error {
    case releasedError
}

class DataManager {
    static let shared = DataManager()

    private var cancellable1: AnyCancellable? = nil
    private var cancellable2: AnyCancellable? = nil

    deinit {
        J1Logger.shared.debug("deinit")
    }

    func deleteAll() {
        Password.deleteAll()
        Site.deleteAll()
        Category.deleteAll()
        
        let viewContext = PersistenceController.shared.container.viewContext
        viewContext.refreshAllObjects()
    }
    
    func backup() -> AnyPublisher<URL, Error> {
        let tempURL = ExportEngine.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        let engines = [Category.self, Site.self, Password.self].map {
            ExportEngine(entity: $0,
                         fileURL: tempURL
                            .appendingPathComponent(String(describing: $0), isDirectory: false)
                            .appendingPathExtension(for: .commaSeparatedText))
        }

        let publishers = engines.map {
            $0.csvPublisher(source: $0.backupPublisher())
        }
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
                        let urls = engines.map { $0.url }
                        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
                        let timestr = ExportEngine.timeString
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
//                    print(arg)
                }

            }
        }.eraseToAnyPublisher()
    }
    
    func export(cryptor: Cryptor) -> AnyPublisher<URL, Error> {
        let tempURL = ExportEngine.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        let nameApp   = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let nameTitle = String(describing: Site.self)
        let timestr   = ExportEngine.timeString
        let fileURL = tempURL
            .appendingPathComponent("\(nameApp)-\(nameTitle)-\(timestr)", isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)

        let engine     = ExportEngine(entity: Site.self, fileURL: fileURL)
        engine.cryptor = cryptor
        let publisher  = engine.csvPublisher(source: engine.exportPublisher())

        return Deferred {
            Future<URL, Error> { promise in
                _ = publisher.sink { completion in
                    engine.close()

                    switch completion {
                    case .finished:
                        promise(.success(engine.url))
                    case .failure(let error):
                        J1Logger.shared.error("error = \(error)")
                        promise(.failure(error))
                    }
                } receiveValue: { arg in
//                    print(arg)
                }

            }
        }.eraseToAnyPublisher()
    }



    func `import`(url: URL, cryptor: CryptorUI) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            let publisher = CSVReaderPublisher<[String: String]>(url: url)
            let subject:  AnyPublisher<Dictionary<String, String>, Error>
                = publisher.tryMap { (parm: [String: String]) -> [String: String] in
                    var dict = parm
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
