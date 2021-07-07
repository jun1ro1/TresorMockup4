//
//  ExportEngine.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/06/12.
//

import Foundation
import Combine
import CoreData

import CSV
import Zip

class ExportEngine {
    private var entity:  PublishableManagedObject.Type
    private var fileURL: URL
    private var stream:  OutputStream
    private var csv:     CSVWriter? = nil
    private var error:   Error?     = nil
    public  var cryptor: Cryptor?   = nil

    init(entity: PublishableManagedObject.Type, fileURL: URL) {
        self.entity  = entity
        self.fileURL = fileURL
        self.stream  = OutputStream(url: self.fileURL, append: false)!
        do {
            self.csv = try CSVWriter(stream: stream)
        } catch let error {
            self.error = error
            J1Logger.shared.error("error = \(error)")
        }
    }

    static var temporaryURL: URL {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: true)
        return tempURL
    }

    var url: URL { return self.fileURL }

    static var timeString: String {
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

    func plainPublisher(publisher: AnyPublisher<[String: String]?, Error>,
                        headerPublisher: AnyPublisher<[String], Error>)
    -> AnyPublisher<[String], Error> {
        return headerPublisher.combineLatest(publisher.prepend(nil))
            .tryMap { (keys, dict) -> [String] in
                guard dict != nil else {
                    return keys
                }
                var dictPlain = dict!
                if let cipher = dictPlain["password"], !cipher.isEmpty {
                    guard self.cryptor != nil else {
                        throw CryptorError.notOpened
                    }
                    let plain = try self.cryptor!.decrypt(cipher: cipher)
                    dictPlain["password"] = plain
                }
                return keys.map { dictPlain[$0] ?? "" }
            }.eraseToAnyPublisher()
    }

    func exportPublisher() -> AnyPublisher<[String], Error> {
        let sortNames = ["title", "url", "userid", "password", "memo", "selectAt"]
        let publisher = self.entity.publisher(sortNames: sortNames, predicate: nil)
        let header    = Just(sortNames)
            .setFailureType(to: Error.self).eraseToAnyPublisher()
        return self.plainPublisher(publisher: publisher, headerPublisher: header)
    }

    func csvPublisher(source: AnyPublisher<[String], Error> )
    -> AnyPublisher<[String], Error> {
        return source
            .tryMap {
                guard self.error == nil else {
                    throw self.error!
                }
                do {
                    try self.csv?.write(row: $0)
                } catch let error {
                    self.error = error
                    throw self.error!
                }
                return $0
            }.eraseToAnyPublisher()
    }

    func close() {
        self.csv?.stream.close()
    }
}
