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

class RestoreManager {
    private var publisher:        AnyPublisher<Bool, Error>? = nil
    private var cancellable:      AnyCancellable? = nil
    private var cancellableLoad:  AnyCancellable? = nil
    private var cancellableLink:  AnyCancellable? = nil

    init(url: URL) {
        let tempURL = ImportEngine.temporaryURL
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

        let entities: [(NSManagedObject.Type, [String])] =
            [(Category.self, ["uuid", "name"]),
             (Site.self    , ["uuid", "url", "title"]),
             (Password.self, ["uuid", "password"])]
        let urls = entities.map { (cls, _) in
            return tempURL.appendingPathComponent(
                "\(cls)" + ".csv", isDirectory: false)
        }
        let csvs = urls.map { (url) in
            return CSVReaderPublisher<[String: String]>(url: url)
        }

        let context = PersistenceController.shared.container.newBackgroundContext()
        let engines = entities.map { (cls, keys) in
                return ImportEngine(entity: cls, searchingKeys: keys, context: context)
            }

        self.publisher = Deferred {
            Future<Bool, Error> { [unowned self] promise in
//                guard let self = self else {
//                    J1Logger.shared.error("released")
//                    promise(.failure(DataManagerError.releasedError))
//                    return
//                }

                 context.perform {
                    let publishers: [AnyPublisher<([String: String], NSManagedObject), Error>]
                        = zip(csvs, engines).map { (csv, engine) in
                            let mopublisher = engine.managedObjectPublisher(publisher: csv.eraseToAnyPublisher())
                            return engine.restorePublisher(publisher: mopublisher)
                        }

                    let loadPublishers = publishers.dropFirst().reduce(publishers[0]) {
                        $0.append($1).eraseToAnyPublisher()
                    }

                    self.cancellableLoad = loadPublishers.sink { [unowned self] completion in
//                        guard let self = self else {
//                            J1Logger.shared.error("released")
//                            promise(.failure(DataManagerError.releasedError))
//                            return
//                        }

                        (urls + [tempURL]).forEach { (url) in
                            do {
                                try FileManager.default.removeItem(at: url)
                            } catch let error {
                                J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
                            }
                        }
                        switch completion {
                        case .finished:
                            J1Logger.shared.debug("completion = \(completion)")
                            let links = engines.map { engine in
                                engine.linkPublisher()
                            }
                            let linkPublishers = links.dropFirst().reduce(links[0]) {
                                $0.append($1).eraseToAnyPublisher()
                            }

                            self.cancellableLink = linkPublishers.sink { completion in
                                switch completion {
                                case .finished:
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
                                    J1Logger.shared.debug("finished")
                                    promise(.success(true))
                                case .failure(let error):
                                    J1Logger.shared.error("error = \(error)")
                                    promise(.failure(error))
                                } // switch
                            } receiveValue: { (val) in
//                                print(val)
                            }

                        case .failure(let error):
                            J1Logger.shared.error("error = \(error)")
                        }
                    } receiveValue: { (dict, _) in
//                        print(dict)
                    } // sink
                } // conext.perform
            } // Deferred
        }.eraseToAnyPublisher()
    } // init

    deinit {
        J1Logger.shared.debug("deinit")
    }

    func sink(receiveCompletion: @escaping ((Subscribers.Completion<Error>) -> Void),
              receiveValue:      @escaping ((Bool) -> Void)) {
        self.cancellable = self.publisher?.sink(receiveCompletion: receiveCompletion,
                                                receiveValue: receiveValue)
    }
}
