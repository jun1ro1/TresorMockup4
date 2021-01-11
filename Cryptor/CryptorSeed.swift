//
//  CryptorSeed.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/01/11.
//

import Foundation
import CryptoKit

// MARK: - CryptorSeed
internal struct CryptorSeed {
    var version: String
    var salt:         Data?
    var rounds:       UInt32
    var key:          SymmetricKey?
    var dateCreated:  Date?
    var dateModified: Date?

    static let label: String = "CryptorSeed"

    init() {
        self.version      = "0"
        self.salt         = nil
        self.rounds       = 1
        self.key          = nil
        self.dateCreated  = nil
        self.dateModified = nil
    }

    init(version: String, salt: Data) {
        self.init()
        self.version = version
        self.salt    = salt
        if self.version == "1" {
            self.rounds = 100000
        }
    }

    init(version: String, salt: Data, key: SymmetricKey) {
        self.init(version: version, salt: salt)
        self.key = key
    }

    init?(_ str: String) {
        let ary = str.split(separator: ":")
        guard ary.count >= 3 else {
            return nil
        }
        guard let keydata = Data(base64Encoded: String(ary[2])) else {
            return nil
        }
        let version = String(ary[0])
        let salt    = Data(base64Encoded: String(ary[1]))
        let key     = SymmetricKey(data: keydata)
        self.init(version: version, salt: salt!, key: key)
    }

    mutating func reset() {
        self.version      = "0"
        self.salt         = nil
        self.rounds       = 1
        self.key          = nil
        self.dateCreated  = nil
        self.dateModified = nil
    }

    var string: String {
        return [
            self.version,
            self.salt?.base64EncodedString() ?? "",
            self.key?.data.base64EncodedString() ?? "",
            ].joined(separator: ":")
    }
    
    static func read() throws -> CryptorSeed? {
        guard var data = try SecureStore.shared.read(label: CryptorSeed.label) else {
            return nil
        }
        defer { data.reset() }

        // get a CryptorSeed string value from SecItem
        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer{ str = "" }

        guard var seed = CryptorSeed(str) else {
            throw CryptorError.SecItemBroken
        }
        seed.dateCreated  = SecureStore.shared.created
        seed.dateModified = SecureStore.shared.modified
        return seed
    }

    static func write(_ seed: CryptorSeed) throws {
        guard var data = seed.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.write(label: CryptorSeed.label, data)
    }

    static func update(_ seed:CryptorSeed) throws {
        guard var data = seed.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.update(label: CryptorSeed.label, data)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: CryptorSeed.label)
    }
} // CryptorSeed
