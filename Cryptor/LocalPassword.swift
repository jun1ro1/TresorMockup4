//
//  LocalPassword.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/09.
//

import Foundation

internal class LocalPassword {
    var password: String? = nil

    static let label: String = "Password"

    init(_ str: String) {
        self.password = str
    }

    func reset() {
        self.password = ""
    }

    var string: String {
        return self.password ?? ""
    }

    static func doesExist() throws -> Bool {
        guard var data =
                try SecureStore.shared.read(label: LocalPassword.label, iCloud: false) else {
            return false
        }
        defer { data.removeAll() }

        guard var str = String(data: data, encoding: .utf8) else {
            return false
        }
        defer { str = "" }

        let val = (str != "")
        return val
    }
    
    static func read() throws -> LocalPassword? {
        guard var data =
                try SecureStore.shared.read(label: LocalPassword.label, iCloud: false) else {
            throw CryptorError.SecItemBroken
        }
        defer { data.removeAll() }

        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer { str = "" }

        return LocalPassword(str)
    }

    static func write(_ passwordStore: LocalPassword) throws {
        guard var data = passwordStore.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.removeAll() }
        try SecureStore.shared.write(label: LocalPassword.label, data, iCloud: false)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: LocalPassword.label, iCloud: false)
    }
} // Validator
