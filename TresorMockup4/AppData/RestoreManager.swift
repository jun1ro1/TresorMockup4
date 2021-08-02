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

public enum RestoreError: Error {
    case cannotCreateTempDir(error: Error)
    case cannotGetFileSize
    case tooLargeFile
    case cancelled
}

extension RestoreError: LocalizedError {
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

struct Progress {
    var phase:            String  = ""
    var countTotal:       Int     = 0
    var count:            Int     = 0
    var progress:         Double  = 0.0
    var step:             Double  = 0.0
    var block:            ((Double) -> Void)?

    init(block: ((Double) -> Void)?) {
        self.block = block
    }

    mutating func countUp() {
        self.count += 1
        self.progress = (self.countTotal == 0) ?
            0.0 : Double(self.count) / Double(self.countTotal)
        if self.progress >= self.step {
            self.step += 1.0 / 32.0
            self.block?(self.progress)
        }
    }
}

class RestoreManager {
    var url:    URL? = nil
    private var phase:            String

    private var engines:          [ImportEngine]  = []
    private var publisher:        PassthroughSubject<(String, Double), Error>
    private var cancellable:      AnyCancellable? = nil
    private var cancellableLoad:  AnyCancellable? = nil
    private var cancellableLink:  AnyCancellable? = nil

    private var context: NSManagedObjectContext? = nil

    //    private var csvs: [CSVReaderPublisher<[String : String]>] = []

    private var progress = Progress {_ in
        Thread.sleep(forTimeInterval: 0.1)
    }

    init() {
        self.url   = nil
        self.phase = ""
        self.publisher = PassthroughSubject<(String, Double), Error>()
    }

    convenience init(url: URL) {
        self.init()
        self.url = url
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
        self.cancellableLink?.cancel()
        self.engines.forEach {
            $0.cancelled = true
        }
        self.cancellableLoad?.cancel()
        self.context?.reset()
        self.publisher.send(completion: .failure(RestoreError.cancelled))
        J1Logger.shared.debug("cancelled")
    }

    private func send() {
        let tempURL = ImportEngine.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
            self.publisher.send(completion: .failure(RestoreError.cannotCreateTempDir(error: error)))
            return
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        let entities: [(NSManagedObject.Type, [String])] =
            [(Category.self, ["uuid", "name"]),
             (Site.self    , ["uuid", "url", "title"]),
             (Password.self, ["uuid", "password"])]
        let urls = entities.map { (cls, _) in
            return tempURL.appendingPathComponent(
                "\(cls)" + ".csv", isDirectory: false)
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

        do {
            try Zip.unzipFile(self.url!, destination: tempURL, overwrite:true, password: nil)
        } catch let error {
            J1Logger.shared.error("Zip.unzipFile = \(error)")
            self.publisher.send(completion: .failure(error))
            return
        }

        let csvs = urls.map { (url) in
            return CSVReaderPublisher<[String: String]>(url: url)
        }

        self.progress.countTotal = 0
        csvs.forEach { (csv) -> Void in
            let countCancellable = csv.replaceError(with: [:])
                .count()
                .sink {
                    self.progress.countTotal += $0
                }
            J1Logger.shared.debug("countCancellabe = \(countCancellable)")
        }
        self.progress.countTotal *= 2



        // DEBUG!!
//        let csvs2 = csvs.map { $0.eraseToAnyPublisher() }
//        let debugPublishers = csvs2.dropFirst().reduce(csvs2[0]) {
//            $0.append($1).eraseToAnyPublisher()
//        }
//        var debugCount = 0
//        let debugCancellable = debugPublishers
//            .subscribe(on: DispatchQueue.global(qos: .background))
//            .sink { completion in
//                J1Logger.shared.debug("completion = \(completion)")
//            } receiveValue: { val in
//                debugCount += 1
//                Thread.sleep(forTimeInterval: 0.1)
//                J1Logger.shared.debug("debugCount = \(debugCount)")
//
//            }
//        J1Logger.shared.debug("debugCancellable = \(debugCancellable)")
//        DispatchQueue.global().asyncAfter(deadline: .now() + 0.7) {
//            debugCancellable.cancel()
//            J1Logger.shared.debug("debugCancellable = \(debugCancellable)")
//        }



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

        self.engines = entities.map { (cls, keys) in
            return ImportEngine(entity: cls, searchingKeys: keys, context: context)
        }
        let engines = self.engines

        context.perform {
            let publishers: [AnyPublisher<([String: String], NSManagedObject), Error>]
                = zip(csvs, engines).map { (csv, engine) in
                    let mopublisher = engine.managedObjectPublisher(publisher: csv.eraseToAnyPublisher())
                    return engine.restorePublisher(publisher: mopublisher)
                }

            let loadPublishers = publishers.dropFirst().reduce(publishers[0]) {
                $0.append($1).eraseToAnyPublisher()
            }

            self.phase = "Loading..."
            self.cancellableLoad = loadPublishers
                .subscribe(on: DispatchQueue.global(qos: .background))
                .sink { completion in
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

                        self.phase = "Linking relations..."
                        self.cancellableLink = linkPublishers
                            .subscribe(on: DispatchQueue.global(qos: .background))
                            .sink { completion in
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
                                    self.publisher.send(completion: .finished)

                                case .failure(let error):
                                    J1Logger.shared.error("error = \(error)")
                                    self.publisher.send(completion: .failure(error))
                                } // switch
                            } receiveValue: { (val) in
                                self.progress.countUp()
                                self.publisher.send((self.phase, self.progress.progress))
                            }

                    case .failure(let error):
                        J1Logger.shared.error("error = \(error)")
                    }
                } receiveValue: { _ in
                    self.progress.countUp()
                    self.publisher.send((self.phase, self.progress.progress))
                } // sink
        } // conext.perform
        J1Logger.shared.debug("end of send")
    } // senf
}
