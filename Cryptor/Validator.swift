//
//  Validator.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/01/11.
//

import Foundation
import CryptoKit

// MARK: -
internal class Validator {
    var hashedMark:    Data? = nil
    var encryptedMark: Data? = nil

    static let label: String = "Validator"

    init?(_ str: String) {
        let ary = str.split(separator: ":")
        guard ary.count >= 2 else {
            return nil
        }
        self.hashedMark     = Data(base64Encoded: String(ary[0]))
        self.encryptedMark  = Data(base64Encoded: String(ary[1]))
    }

    init?(key: SymmetricKey) {
        guard var mark: Data = try? RandomData.shared.get(count: 16) else {
            return nil
        }
        defer { mark.reset() }

        // get a hashed mark
        self.hashedMark = mark.hash()

        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("mark=\(mark as NSData)")
        J1Logger.shared.debug("hashedMark=\(self.hashedMark! as NSData)")
        #endif

        self.encryptedMark = try? mark.encrypt(using: key)
        guard self.encryptedMark != nil else {
            return nil
        }

        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("encryptedMark=\(self.encryptedMark! as NSData)")
        #endif
    }

    func reset() {
        self.hashedMark?.reset()
        self.encryptedMark?.reset()
    }

    var string: String {
        return [
            self.hashedMark?.base64EncodedString() ?? "",
            self.encryptedMark?.base64EncodedString() ?? "",
            ].joined(separator: ":")
    }

    func validate(key: SymmetricKey) -> Bool {
        guard self.hashedMark != nil && self.encryptedMark != nil else {
            return false
        }

        do {
            // get binary Mark
            var decryptedMark: Data = try self.encryptedMark!.decrypt(using: key)
            defer { decryptedMark.reset() }

            var hashedDecryptedMark: Data = decryptedMark.hash()
            defer { hashedDecryptedMark.reset() }

            #if DEBUG && DEBUG_CRYPTOR_UT
            J1Logger.shared.debug("hashedMark=\(hashedMark! as NSData)")
            J1Logger.shared.debug("hashedDecryptedMark=\(hashedDecryptedMark as NSData)")
            #endif

            return hashedMark == hashedDecryptedMark
        } catch {
            return false
        }
    }

    static func read() throws -> Validator? {
        guard var data = try SecureStore.shared.read(label: Validator.label) else {
            throw CryptorError.SecItemBroken
        }
        defer { data.reset() }

        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer { str = "" }

        guard let validator = Validator(str) else {
            throw CryptorError.SecItemBroken
        }
        return validator
    }

    static func write(_ validator: Validator) throws {
        guard var data = validator.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.write(label: Validator.label, data)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: Validator.label)
    }
} // Validator
