//
//  ImportManager.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/08/03.
//

import Foundation

//
//  RestoreManager.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/07/08.
//
// https://www.advancedswift.com/read-file-combine-swift/

import Foundation
import CoreData
import Combine

import CSV
import Zip

public enum ImportError: Error {
    case cannotCreateTempDir(error: Error)
    case cannotGetFileSize
    case tooLargeFile
    case cancelled
}

extension ImportError: LocalizedError {
    /// Returns a description of the error.
    public var errorDescription: String?  {
        switch self {
        case .cannotCreateTempDir(let error):
            return "Cannot create temporary directory error = \(error)"
        case .cannotGetFileSize:
            return "Cannot get file size"
        case .tooLargeFile:
            return "Too Large file"
        case .cancelled:
            return "Cancelled"
        }
    }
}

class ImportManager: LoaderManager {
    var         url:              URL?            = nil
    var         cryptor:          CryptorUI?
    private var phase:            String

    private var engine:           ImportEngine?   = nil
    private var publisher:        PassthroughSubject<(String, Double), Error>
    private var cancellable:      AnyCancellable? = nil
    private var cancellableLoad:  AnyCancellable? = nil

    private var context: NSManagedObjectContext?  = nil

    //    private var csvs: [CSVReaderPublisher<[String : String]>] = []

    private var progress = Progress {_ in
        Thread.sleep(forTimeInterval: 0.05)
    }

    init() {
        self.url   = nil
        self.phase = ""
        self.publisher = PassthroughSubject<(String, Double), Error>()
    }

    convenience init(url: URL, cryptor: CryptorUI) {
        self.init()
        self.url     = url
        self.cryptor = cryptor
    }

    deinit {
        J1Logger.shared.debug("deinit")
    }

    func sink(receiveCompletion: @escaping ((Subscribers.Completion<Error>) -> Void),
              receiveValue:      @escaping ((String, Double) -> Void)) {
        self.cancellable = self.publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion,
                  receiveValue: receiveValue)
        self.send()
    }

    func cancel() {
        self.engine?.cancelled = true
        self.cancellableLoad?.cancel()
        self.context?.reset()
        self.publisher.send(completion: .failure(RestoreError.cancelled))
        J1Logger.shared.debug("cancelled")
    }

    private func send() {
        if self.url == nil {
            return
        }

        let attr: [FileAttributeKey: Any]
        do {
            attr = try FileManager.default.attributesOfItem(atPath: self.url!.path)
        } catch let error {
            J1Logger.shared.error("attributeOfItem error  = \(error)")
            self.publisher.send(completion: .failure(error))
            return
        }
        guard let fileSize = attr[.size] as? Int64 else {
            J1Logger.shared.error("attr[.size]")
            self.publisher.send(completion: .failure(RestoreError.cannotGetFileSize))
            return
        }
        guard fileSize <= 512 * 1024 * 1024 else {
            J1Logger.shared.error("file size = \(fileSize)")
            self.publisher.send(completion: .failure(RestoreError.tooLargeFile))
            return
        }
        let csv = CSVReaderPublisher<[String: String]>(url: self.url!)

        self.progress.countTotal = 0
        let countCancellable = csv
            .replaceError(with: [:])
            .count()
            .sink {
                self.progress.countTotal += $0
            }
        J1Logger.shared.debug("countCancellabe = \(countCancellable)")

        self.context = PersistenceController.shared.container.newBackgroundContext()
        let context = self.context!
        if context.hasChanges {
            do {
                J1Logger.shared.debug("save context")
                try context.save()
            } catch {
                let nsError = error as NSError
                J1Logger.shared.error("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            J1Logger.shared.debug("save context")
        }
        context.reset()

        self.engine = ImportEngine(entity: Site.self, searchingKeys: ["url", "title"], context: context)
        let engine = self.engine!

        context.perform {
            let kindTrash = Int(CategoryKind.trash.rawValue)
            let compoundPredicate = NSPredicate(format: "category == nil OR category.kind !=\(kindTrash)")
            let mopublisher       = engine.managedObjectPublisher(
                publisher: csv.eraseToAnyPublisher(), compoundPredicate: compoundPredicate)
            let loadPublisher     = engine.setValuePublisher(publisher: mopublisher, cryptor: self.cryptor)

            self.phase = "Importing..."
            self.cancellableLoad = loadPublisher
                .subscribe(on: DispatchQueue.global(qos: .background))
                .sink { completion in
                    DispatchQueue.main.async {
                        self.cryptor?.close(keep: false)
                    }
                    switch completion {
                    case .finished:
                        J1Logger.shared.debug("completion = \(completion)")
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
                        self.publisher.send(completion: .finished)
                    case .failure(let error):
                        context.reset()
                        J1Logger.shared.error("error = \(error)")
                    }
                } receiveValue: { _ in
                    self.progress.countUp()
                    self.publisher.send((self.phase, self.progress.progress))
                } // sink
        } // conext.perform
        J1Logger.shared.debug("end of send")
    } // senf



//    func `import`(url: URL, cryptor: CryptorUI) {
//        let context = PersistenceController.shared.container.newBackgroundContext()
//        context.perform {
//            let publisher = CSVReaderPublisher<[String: String]>(url: url)
//            let subject:  AnyPublisher<Dictionary<String, String>, Error>
//                = publisher.tryMap { (parm: [String: String]) -> [String: String] in
//                    var dict = parm
//                    if let plain = dict["password"], !plain.isEmpty {
//                        let proxy = PasswordProxy()
//                        proxy.plain = plain
//                        try proxy.endecrypt(cryptor: cryptor)
//                        dict["password"] = proxy.cipher
//                        //                        dict["passwordHash"] = proxy.passwordHash
//                    }
//                    return dict
//                }.eraseToAnyPublisher()
//            let loaderSite = Restorer<Site>(searchingKeys: ["url", "title"], context: context)
//            loaderSite.load(from: subject)
//
//            if context.hasChanges {
//                do {
//                    try context.save()
//                } catch {
//                    let nsError = error as NSError
//                    J1Logger.shared.error("Unresolved error \(nsError), \(nsError.userInfo)")
//                }
//                J1Logger.shared.debug("save context")
//            }
//            context.reset()
//            DispatchQueue.main.async {
//                cryptor.close(keep: false)
//            }
//        }
//    } // func
}
