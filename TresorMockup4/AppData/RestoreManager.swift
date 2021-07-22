//
//  RestoreManager.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/07/08.
//

import Foundation
import CoreData
import Combine

import CSV
import Zip

class RestoreManager {
    private var url:              URL
    private var publisher:        PassthroughSubject<Double, Error>
    private var cancellable:      AnyCancellable? = nil
    private var cancellableLoad:  AnyCancellable? = nil
    private var cancellableLink:  AnyCancellable? = nil
    private var progress:         Double          = 0.0
    private var phases:           Int             = 3
    private var step:             Double          = 0.0


    init(url: URL) {
        self.url = url
        self.publisher = PassthroughSubject<Double, Error>()
    } // init

    deinit {
        J1Logger.shared.debug("deinit")
    }

    func sink(receiveCompletion: @escaping ((Subscribers.Completion<Error>) -> Void),
              receiveValue:      @escaping ((Double) -> Void)) {
        self.cancellable = self.publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion,
                  receiveValue: receiveValue)
        self.send()
    }

    private func send() {
        let tempURL = ImportEngine.temporaryURL
        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch let error {
            J1Logger.shared.error("createDirectory error = \(error)")
            self.publisher.send(completion: .failure(error))
            return
        }
        J1Logger.shared.info("tempURL = \(tempURL)")

        do {
            try Zip.unzipFile(url, destination: tempURL, overwrite: true, password: nil, progress: { prog in
                self.progress = prog / Double(self.phases)
            }, fileOutputHandler: nil)
        } catch let error {
            J1Logger.shared.error("Zip.unzipFile = \(error)")
            self.publisher.send(completion: .failure(error))
            return
        }

        let entities: [(NSManagedObject.Type, [String])] =
            [(Category.self, ["uuid", "name"]),
             (Site.self    , ["uuid", "url", "title"]),
             (Password.self, ["uuid", "password"])]
        let urls = entities.map { (cls, _) in
            return tempURL.appendingPathComponent(
                "\(cls)" + ".csv", isDirectory: false)
        }

        // file size check

        let csvs = urls.map { (url) in
            return CSVReaderPublisher<[String: String]>(url: url)
        }

        var linesTotal = 0
        csvs.forEach { (csv) -> Void in
            _ = csv.replaceError(with: [:])
                .count()
                .sink {
                    linesTotal += $0
                }
        }
        var linesCurrent = 0

        let context = PersistenceController.shared.container.newBackgroundContext()

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

        let engines = entities.map { (cls, keys) in
            return ImportEngine(entity: cls, searchingKeys: keys, context: context)
        }

        context.perform {
            let publishers: [AnyPublisher<([String: String], NSManagedObject), Error>]
                = zip(csvs, engines).map { (csv, engine) in
                    let mopublisher = engine.managedObjectPublisher(publisher: csv.eraseToAnyPublisher())
                    return engine.restorePublisher(publisher: mopublisher)
                }

            let loadPublishers = publishers.dropFirst().reduce(publishers[0]) {
                $0.append($1).eraseToAnyPublisher()
            }

            self.cancellableLoad = loadPublishers.sink { completion in
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
                            self.publisher.send(completion: .finished)

                        case .failure(let error):
                            J1Logger.shared.error("error = \(error)")
                            self.publisher.send(completion: .failure(error))
                        } // switch
                    } receiveValue: { (val) in
                        //                        linesCurrent += 1
                        //                    self.publisher.send(Double(linesCurrent) / Double(linesTotal))
                    }

                case .failure(let error):
                    J1Logger.shared.error("error = \(error)")
                }
            } receiveValue: { _ in
                linesCurrent += 1
                let progress = Double(linesCurrent) / Double(linesTotal)
                self.publisher.send(progress)
                if progress >= self.step {
                    self.step += 1.0 / 16.0
                    Thread.sleep(forTimeInterval: 0.1)
                }
            } // sink
        } // conext.perform
    } // senf
}
