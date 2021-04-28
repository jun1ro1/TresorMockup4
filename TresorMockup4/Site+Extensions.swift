//
//  Site+Extensions.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/21.
//
// https://qiita.com/yosshi4486/items/7a2434e0b855d81d6ea9

import Foundation
import CoreData
import Combine
import CSV

extension Site {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        self.setPrimitiveValue(now, forKey: "createdAt")        
        self.setPrimitiveValue(UUID(), forKey: "uuid")
        self.setPrimitiveValue(ManagedObjectVersion, forKey: "version")
        
        self.setPrimitiveValue(8, forKey: "maxLength")
        self.setPrimitiveValue(CypherCharacterSet.AlphaNumericsSet.rawValue, forKey: "charSet")
        
        // https://developer.apple.com/documentation/objectivec/nsobject/keyvalueobservingpublisher
        // https://developer.apple.com/documentation/swift/cocoa_design_patterns/using_key-value_observing_in_swift
        // https://qiita.com/BlueEventHorizon/items/bf37428b54b937728dc7
        // https://developer.apple.com/documentation/swift/cocoa_design_patterns/using_key-value_observing_in_swift
        // https://stackoverflow.com/questions/60386000/how-to-use-combine-framework-nsobject-keyvalueobservingpublisher
        // https://www.apeth.com/UnderstandingCombine/publishers/publisherskvo.html
        // https://augmentedcode.io/2020/11/08/observing-a-kvo-compatible-model-in-swiftui-and-mvvm/
      }
    
//    override public func awakeFromFetch() {
//        super.awakeFromFetch()
//        self.observation = self.observe(\.password, options: [.new, .old], changeHandler: Self.updatePassword)
//    }
    
    public func setPassword(cipher newPassCipher: String, plain newPassPlain: String) throws {
        guard let viewContext = self.managedObjectContext else { return }
        let passwords = (self.passwords?.allObjects as? [Password] ?? [])
                .sorted { (x, y) -> Bool in
                    let xc = x.createdAt ?? Date(timeIntervalSince1970: 0)
                    let yc = y.createdAt ?? Date(timeIntervalSince1970: 0)
                    return xc < yc
                }
        let newPassHash = try newPassPlain.hash()

        // save old password
        if let oldPassStr  = self.password, let oldPassHash = self.passwordHash {
            if passwords.first(where: { $0.passwordHash == oldPassHash }) == nil {
                let oldPassword = Password(context: viewContext)
                oldPassword.password     = oldPassStr
                oldPassword.passwordHash = self.passwordHash
                oldPassword.length       = self.length
                oldPassword.site         = self
                self.addToPasswords(oldPassword)
            }
        }
        
        self.password     = newPassCipher
        self.passwordHash = try newPassPlain.hash()
        self.length       = Int16(newPassPlain.count)

        let newPassword = { () -> Password in
            var p = passwords.first(where: { $0.passwordHash == newPassHash })
            if p != nil { return p! }
            p = Password(context: viewContext)
            p!.password     = self.password
            p!.passwordHash = self.passwordHash
            p!.length       = self.length
            p!.site         = self
            self.addToPasswords(p!)
            return p!
        }()
        newPassword.toCurrent()
    }
    
    public override func willSave() {
        var state = ObjectState(rawValue: (self.value(forKey: "state") as? Int16) ?? 0)
        _ = state.insert(ObjectState.saved)
        self.setPrimitiveValue(state.rawValue, forKey: "state")
    }
    
    public var currentPassword: Password? {
        return self.passwords?.first {($0 as! Password).current} as? Password
    }
    
    class func delete(_ site: Site, context: NSManagedObjectContext) {
        site.passwords?.allObjects.forEach { pass in
            context.delete(pass as! NSManagedObject)
        }
        context.delete(site)
    }
    
    class func backup(url: URL) -> URL {
        let fileURL = url
            .appendingPathComponent(String(describing: Self.self), isDirectory: false)
            .appendingPathExtension(for: .commaSeparatedText)
        Self.backup(url: fileURL, sortNames: ["titleSort", "title", "url", "userid", "password"])
        return fileURL
    }
    

    class func headerPublisher(publisher: AnyPublisher<Dictionary<String, String>, Error>,
                               sortNames: [String] = [])
    -> AnyPublisher<[String], Error> {
        publisher.first().map {
            var names    = Array($0.keys)
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

    class func tablePublisher2(publisher: AnyPublisher<Dictionary<String, String>, Error>,
                               sortNames: [String] = [])
    -> AnyPublisher<[String], Error> {
        return Self.headerPublisher(publisher:publisher, sortNames: sortNames)
            .combineLatest(publisher.prepend([:]))
            .map { (keys, dict) -> [String] in
                dict == [:] ? keys : keys.map { dict[$0] ?? "" }
            }.eraseToAnyPublisher()
    }

    class func export(url: URL) {
        guard let stream = OutputStream(url: url, append: false) else {
            J1Logger.shared.error("OutputStream error url=\(url)")
            return
        }
        let csv: CSVWriter
        do {
            csv = try CSVWriter(stream: stream)
        } catch let error {
            J1Logger.shared.error("CSVWriter fails=\(error)")
            return
        }
        
        let sortNames = ["title", "url", "userid", "password", "memo"]
        _ = Self.tablePublisher2(publisher: Self.publisher(sortNames: sortNames),
                                 sortNames: sortNames)
            .map { values -> [String] in
                let num = min(sortNames.count, values.count)
                return Array(values[0..<num])
            }
            .sink { completion in
            csv.stream.close()
            switch completion {
            case .finished:
                J1Logger.shared.debug("finished")
            case .failure(let error):
                J1Logger.shared.error("error = \(error)")
            }
        } receiveValue: { values in
            do {
                try csv.write(row: values)
            } catch let error {
                J1Logger.shared.error("error = \(error)")
            }
        }
    }
}
