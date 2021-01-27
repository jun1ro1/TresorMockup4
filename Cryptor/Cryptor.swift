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
    private  var timer:  Timer?       = nil
    internal var key:    SessionKey?  = nil

//    private var mutex = NSLock()
//    var authenticated: Bool {
//        get {
//            self.mutex.lock()
//            let val = self.opened_private
//            self.mutex.unlock()
//            return val
//        }
//        set {
//            self.mutex.lock()
//            self.opened_private = newValue
//            self.mutex.unlock()
////            if newValue {
////                DispatchQueue.global(qos: .background)
////                    .asyncAfter(deadline: .now() + Cryptor.DURATION) {
////                        J1Logger.shared.debug("authenticated time out=\(Cryptor.DURATION)")
////                        self.opened_private = false
////                    }
////            }
//        }
//    }
    
    func open(password: String,
              _ block: ((Bool) -> Void)? = nil) throws {
        if Cryptor.core.isPrepared {
            do {
                try Cryptor.core.prepare(cryptor: self, password: password) // excep
            } catch {
                block?(false)
            }
        }
        else {
            do {
                try Cryptor.core.register(cryptor: self, password: password)
            } catch {
                block?(false)
            }
       }
        block?(true)
    }
    
    func close() throws {
        try Cryptor.core.close(cryptor: self)
        self.key   = nil
    }
    
    func timeOut(_ duration: Double = 30.0,
                 _ block: @escaping () -> Void = {}) {
        if let t = self.timer, t.isValid {
            t.invalidate()
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval( duration ),
                                          repeats: false) { _ in
            J1Logger.shared.debug("authenticated time out=\(duration)")
            block()
            try? self.close()
        }
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
