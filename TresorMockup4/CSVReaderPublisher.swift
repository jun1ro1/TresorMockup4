//
//  CSVPublisher.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/03/13.
//

import Foundation
import Combine
import CSV

// https://www.donnywals.com/understanding-combines-publishers-and-subscribers/
// https://thoughtbot.com/blog/lets-build-a-custom-publisher-in-combine

enum CSVPublisherError: Error {
    case notFound(url: URL)
    case notOpened(url: URL)
    case csvReaderError(error: Error)
    case headerNotFound
}

struct CSVReaderPublisher<Output>: Publisher {
    typealias Output = [String: String]
    typealias Failure = Error

    private var url: URL

    init(url: URL) {
        self.url = url
    }

    func receive<S>(subscriber: S)
    where S : Subscriber, Error == S.Failure, [String : String] == S.Input {
        let subscription = CSVReaderSubscription<Output, S>(url: url, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

extension CSVReaderPublisher {
    class CSVReaderSubscription<Output, S: Subscriber>: Subscription
    where S.Input == [String: String], S.Failure == Error {

        private var url:        URL
        private var subscriber: S?         = nil
        private var error:      Error?     = nil
        private var csv:        CSVReader? = nil
        private var header:     [String]?  = nil

        init(url: URL, subscriber: S) {
            self.url        = url
            self.subscriber = subscriber

            guard let stream = InputStream(url: self.url) else {
                J1Logger.shared.error("InputStream error url=\(self.url)")
                self.error = CSVPublisherError.notFound(url: self.url)
                return
            }

            do {
                self.csv = try CSVReader(stream: stream, hasHeaderRow: true)
            } catch let error {
                J1Logger.shared.error("CSVReader fails=\(error)")
                self.error = CSVPublisherError.csvReaderError(error: error)
                return
            }
        }

        func request(_ demand: Subscribers.Demand) {
            guard let subscriber = self.subscriber else {
                return
            }

            if self.error != nil {
                subscriber.receive(completion: .failure(self.error!))
                return
            }

            if self.csv == nil {
                self.error = CSVPublisherError.notOpened(url: self.url)
            }

            var demand = demand
            while demand > 0 {
                if self.header == nil {
                    self.header = self.csv?.headerRow
                }
                if self.header == nil {
                    self.error = CSVPublisherError.headerNotFound
                }

                if self.error != nil {
                    subscriber.receive(completion: .failure(self.error!))
                    break
                }
                guard let row = self.csv?.next() else {
                    subscriber.receive(completion: .finished)
                    break
                }

                let dict = Dictionary(uniqueKeysWithValues: Swift.zip(self.header!, row))
                demand -= 1
                demand += subscriber.receive(dict)
            }
        }

        func cancel() {
            self.subscriber = nil
        }

    }
}

//    var subject: PassthroughSubject<Dictionary<String, String>, Error> {
//        get {
//            return self.subjectPrivate
//        }
//    }
//
//    init(url: URL) {
//        self.url = url
//    }
//
//    func send() {
//        guard let stream = InputStream(url: self.url) else {
//            J1Logger.shared.error("InputStream error url=\(self.url)")
//            self.subjectPrivate.send(completion: .failure(NSCoderValueNotFoundError as! Error))
//            return
//        }
//
//        let csv: CSVReader
//        do {
//            csv = try CSVReader(stream: stream, hasHeaderRow: true)
//        } catch let error {
//            J1Logger.shared.error("CSVReader fails=\(error)")
//            self.subjectPrivate.send(completion: .failure(error))
//            return
//        }
//        guard let header = csv.headerRow else {
//            J1Logger.shared.error("header not found")
//            self.subjectPrivate.send(completion: .failure(NSCoderValueNotFoundError as! Error))
//            return
//        }
//
//        while let row = csv.next() {
//            let dict = Dictionary(uniqueKeysWithValues: zip(header, row))
//            self.subjectPrivate.send(dict)
//        }
//        self.subjectPrivate.send(completion: .finished)
//    }
//}
