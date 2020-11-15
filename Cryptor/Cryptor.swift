//
//  Cryptor.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/07.
//

import Foundation
import CryptoKit

/// The class to encrypt and decrypt a string or data
public class Cryptor {

    /// A class variable for a singleton pattern
    static var shared: Cryptor = Cryptor()

    /// A calss variable to access the class `CryptorCore`
    internal static var core: CryptorCore = CryptorCore.shared

    /// The instance variable to store a session key
    var key: SymmetricKey?
    
    /// Initializer
    init() {
        self.key = nil
    }

    static func prepare(password: String) throws {
        try Cryptor.core.prepare(password: password)
    }

    static var isPrepared: Bool = {
        return Cryptor.core.isPrepared
    }()

    func open(password: String) throws {
        self.key = try Cryptor.core.open(password: password, cryptor: self) // excep
    }
    
    func close() throws {
        try Cryptor.core.close(cryptor: self)
        self.key = nil
    }
    
    func open(password: String, _ body:() throws -> Void ) throws {
        try self.open(password: password)
        defer {
            try? self.close()
        }
        try body()
    }

    func change(password oldpass: String, to newpass: String) throws {
        guard self.key == nil else {
            throw CryptorError.notOpened
        }
        return try Cryptor.core.change(password: oldpass, to: newpass)
    }
    
    func encrypt(plain: Data) throws -> Data {
        guard self.key != nil else {
            throw CryptorError.notOpened
        }
        return try Cryptor.core.encrypt(cryptor: self, plain: plain)
    }

    func decrypt(cipher: Data) throws -> Data {
        guard self.key != nil else {
            throw CryptorError.notOpened
        }
        return try Cryptor.core.decrypt(cryptor: self, cipher: cipher)
    }

    func encrypt(plain: String) throws -> String {
        guard self.key != nil else {
            throw CryptorError.notOpened
        }
        return try Cryptor.core.encrypt(cryptor: self, plain: plain)
    }

    func decrypt(cipher: String) throws -> String {
        guard self.key != nil else {
            throw CryptorError.notOpened
        }
        return try Cryptor.core.decrypt(cryptor: self, cipher: cipher)
    }
}
