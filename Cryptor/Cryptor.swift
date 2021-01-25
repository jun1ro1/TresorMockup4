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
    
    private static let DURATION = DispatchTimeInterval.seconds(30)

    /// The instance variable to store a session key
    private  var opened_private: Bool      = false
    internal var key:    SessionKey?       = nil
    internal var block:  ((Bool) -> Void)? = nil
    
    init(_ block: @escaping (Bool) -> Void = {_ in }) {
        self.block = block
    }
    
    private var mutex = NSLock()
    var opened: Bool {
        get {
            self.mutex.lock()
            let val = self.opened_private
            self.mutex.unlock()
            return val
        }
        set {
            self.mutex.lock()
            self.opened_private = newValue
            self.mutex.unlock()
            if newValue {
                DispatchQueue.global(qos: .background)
                    .asyncAfter(deadline: .now() + Cryptor.DURATION) {
                        J1Logger.shared.debug("authenticated time out=\(Cryptor.DURATION)")
                        self.opened_private = false
                        self.block?(false)
                    }
            }
        }
    }
    
    func open(password: String) throws {
        if Cryptor.core.isPrepared {
            do {
                try Cryptor.core.prepare(cryptor: self, password: password) // excep
            } catch {
                self.block?(false)
                self.block = nil
            }
        }
        else {
            do {
                try Cryptor.core.register(cryptor: self, password: password)
            } catch {
                self.block?(false)
                self.block = nil
            }
       }
        self.opened = true
        self.block?(true)
    }
    
    func close() throws {
        self.opened = false
        try Cryptor.core.close(cryptor: self)
        self.key   = nil
        self.block?(false)
        self.block = nil
    }
    
//    func open(password: String, _ body:() throws -> Void ) throws {
//        try self.open(password: password)
//        defer {
//            try? self.close()
//        }
//        try body()
//    }
    
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
