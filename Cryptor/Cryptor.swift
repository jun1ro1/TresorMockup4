//
//  Cryptor.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/07.
//

import Foundation
import CryptoKit


import Introspect

/// The class to encrypt and decrypt a string or data
public class Cryptor {
    /// A calss variable to access the class `CryptorCore`
    internal static var core: CryptorCore = CryptorCore.shared
    
    /// The instance variable to store a session key
    internal var key:    SessionKey?  = nil

    func open(password: String,
              _ block: ((Bool?) -> Void)? = nil) throws {
        if Cryptor.core.isPrepared {
            do {
                try Cryptor.core.prepare(cryptor: self, password: password) // excep
            } catch {
                block?(nil)
            }
        }
        else {
            do {
                try Cryptor.core.register(cryptor: self, password: password)
            } catch {
                block?(nil)
            }
       }
        block?(true)
    }
    
    func close(_ block: ((Bool) -> Void)? = nil) throws {
        try Cryptor.core.close(cryptor: self)
        self.key   = nil
        block?(false)
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
