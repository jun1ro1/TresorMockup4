//
//  CryptorCore.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/03.
//

import Foundation
import CryptoKit
import CommonCrypto

typealias InterKey              = SymmetricKey
typealias SessionKey            = SymmetricKey
typealias KeyEncryptionKey      = SymmetricKey
typealias ContentsEncryptionKey = SymmetricKey

// MARK: -
private struct Session {
    var cryptor: Cryptor
    var itk:     InterKey
    // Inter key: the KEK(Key kncryption Key) encrypted using SEK(Session Key)
    
    init(cryptor: Cryptor, itk: InterKey) {
        self.cryptor = cryptor
        self.itk  = itk
    }
}

private struct Sessions {
    private var sessions: [Int: Session] = [:]
    private var mutex: NSLock = NSLock()
    
    var count: Int {
        self.mutex.lock()
        let count = self.sessions.count
        self.mutex.unlock()
        return count
    }
    
    var first: Session? {
        self.mutex.lock()
        let session = self.sessions.first?.value
        self.mutex.unlock()
        return session
    }
    
    mutating func add(cryptor: Cryptor, session: Session) {
        self.mutex.lock()
        self.sessions[ObjectIdentifier(cryptor).hashValue] = session
        self.mutex.unlock()
    }
    
    mutating func remove(cryptor: Cryptor) -> Bool {
        self.mutex.lock()
        let result = self.sessions.removeValue(forKey: ObjectIdentifier(cryptor).hashValue)
        self.mutex.unlock()
        return result != nil
    }
    
    func get(cryptor: Cryptor) -> Session? {
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()
        return session
    }
}

// MARK: -
internal class CryptorCore {
    // constants
    public static let MAX_PASSWORD_LENGTH = 1000
    
    // instance variables
    private var sessions: Sessions = Sessions()
    private var mutex: NSLock = NSLock()
    
    static var shared = CryptorCore()
    
    var isPrepared: Bool {
        do {
            return try SecureStore.shared.doseExist(label: CryptorSeed.label)
        }
        catch {
            return false
        }
    }
    
    private init() {}
    
    // MARK: - private methods
    private func getKEK(password: String, seed: CryptorSeed) throws -> KeyEncryptionKey {
        // check password
        guard case 1...CryptorCore.MAX_PASSWORD_LENGTH = password.count else {
            throw CryptorError.outOfRange
        }
        
        // convert the password to a Data
        guard var binPASS = password.data(using: .utf8, allowLossyConversion: true) else {
            throw CryptorError.invalidCharacter
        }
        defer { binPASS.reset() }
        
        // derivate an CEK with the password and the SALT
        guard var salt: Data = seed.salt else {
            throw CryptorError.SecItemBroken
        }
        defer { salt.reset() }
        
        // get pseudo random key
        let prk: SymmetricKey = SymmetricKey(data: binPASS.hash())
        
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        let kek = HKDF<SHA256>.deriveKey(inputKeyMaterial: prk, salt: salt, outputByteCount: 32)                
        self.mutex.unlock()
        
        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("KEK=\(kek.data as NSData)")
        #endif
        return kek
    }
    
    func engage(cryptor: Cryptor, _ kek: KeyEncryptionKey) throws {
        var sek: SessionKey = SymmetricKey(size: .bits256)
        defer { sek.reset() }
        
        var itk: InterKey = try SymmetricKey(data: kek.data.encrypt(using: sek))
        defer { itk.reset() }
        
        cryptor.key = sek
        let session = Session(cryptor: cryptor, itk: itk)
        self.sessions.add(cryptor: cryptor, session: session)
    }
    
    func register(cryptor: Cryptor, password: String) throws {
        guard !self.isPrepared else {
            throw CryptorError.alreadyRegistered
        }
        
        // convert the password to a Data
        guard var binPASS: Data = password.data(using: .utf8, allowLossyConversion: true) else {
            throw CryptorError.invalidCharacter
        }
        defer { binPASS.reset() }
        
        // create a salt
        var salt: Data = try RandomData.shared.get(count: 16)
        defer { salt.reset() }
        
        // create a CryptorSeed
        var seed = CryptorSeed(version: "1", salt: salt)
        
        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: password, seed: seed)
        defer { kek.reset() }
        
        // create a CEK
        var cek: ContentsEncryptionKey = SymmetricKey(size: .bits256)
        defer { cek.reset() }
        
        // create a Validator
        guard let validator = Validator(key: cek) else {
            throw CryptorError.unexpected
        }
        defer { validator.reset() }
        
        // encrypt the CEK with the KEK
        // https://stackoverflow.com/questions/25754147/issue-using-cccrypt-commoncrypt-in-swift
        // https://stackoverflow.com/questions/37680361/aes-encryption-in-swift
        var cekEnc: SymmetricKey = try SymmetricKey(data: cek.data.encrypt(using: kek))
        defer { cekEnc.reset() }
        seed.key = cekEnc
        
        try CryptorSeed.write(seed)
        try Validator.write(validator)
        
        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("salt=\(salt as NSData)")
        J1Logger.shared.debug("kek=\(kek.data as NSData)")
        J1Logger.shared.debug("cek=\(cek.data as NSData)")
        J1Logger.shared.debug("cekEnc=\(cekEnc.data as NSData)")
        #endif
        
        try self.engage(cryptor: cryptor, kek)
    }
    
    func prepare(cryptor: Cryptor, password: String) throws {
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.SecItemBroken
        }
        defer { seed.reset() }
        
        guard let validator = try Validator.read() else {
            throw CryptorError.SecItemBroken
        }
        defer { validator.reset() }
        
        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }
        
        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: password, seed: seed)
        defer{ kek.reset() }
        
        // get a CEK
        var cek = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer{ cek.reset() }
        
        guard validator.validate(key: cek) == true else {
            throw CryptorError.wrongPassword
        }
        
        try self.engage(cryptor: cryptor, kek)
    }
    
    func close(cryptor: Cryptor) throws {
        guard self.sessions.remove(cryptor: cryptor) else {
            throw CryptorError.notOpened
        }
    }
    
    func closeAll() throws {
        var count = self.sessions.count
        while let session = self.sessions.first {
            try self.close(cryptor: session.cryptor)
            count -= 1
        }
    }
    
    func change(password oldpass: String, to newpass: String) throws {
        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }
        
        guard let validator = try Validator.read() else {
            throw CryptorError.notPrepared
        }
        defer { validator.reset() }
        
        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }
        
        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: oldpass, seed: seed)
        defer{ kek.reset() }
        
        // get a CEK
        var cek = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer{ cek.reset() }
        
        guard validator.validate(key: cek) == true else {
            throw CryptorError.wrongPassword
        }
        
        // check CEK
        guard validator.validate(key: cek) == true else {
            #if DEBUG
            J1Logger.shared.debug("validate=false")
            #endif
            throw CryptorError.wrongPassword
        }
        
        // change KEK
        var newkek = try self.getKEK(password: newpass, seed: seed)
        defer { newkek.reset() }
        
        // crypt a CEK with a new KEK
        var newcekEnc: SymmetricKey = try SymmetricKey(data: cek.data.encrypt(using: newkek))
        defer { newcekEnc.reset() }
        
        seed.key = newcekEnc
        try CryptorSeed.update(seed)
        
        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("newkek   =\(newkek.data)")
        J1Logger.shared.debug("cek      =\(cek.data)")
        J1Logger.shared.debug("newkekEnc=\(newcekEnc.data)")
        #endif
    }
    
    func getCEK(cryptor: Cryptor) throws -> ContentsEncryptionKey {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        
        let session = self.sessions.get(cryptor: cryptor)
        
        #if DEBUG && DEBUG_CRYPTOR_UT
        J1Logger.shared.debug("session.itk=\(String(describing: session?.itk.data))")
        #endif
        guard var itk = session?.itk else {
            throw CryptorError.notOpened
        }
        defer { itk.reset() }
        
        var kek = try SymmetricKey(data: itk.data.decrypt(using: sek))
        defer { kek.reset() }
        
        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }
        
        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }
        
        let  cek: SymmetricKey = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        return cek
    }
    
    func encrypt(cryptor: Cryptor, plain: Data) throws -> Data {
        let cek = try self.getCEK(cryptor: cryptor)
        return try plain.encrypt(using: cek)
    }
    
    func decrypt(cryptor: Cryptor, cipher: Data) throws -> Data {
        let cek = try self.getCEK(cryptor: cryptor)
        return try cipher.decrypt(using: cek)
    }
    
    func encrypt(cryptor: Cryptor, plain: String) throws -> String {
        let cek = try self.getCEK(cryptor: cryptor)
        return try plain.encrypt(using: cek)
    }
    
    func decrypt(cryptor: Cryptor, cipher: String) throws -> String {
        let cek = try self.getCEK(cryptor: cryptor)
        return try cipher.decrypt(using: cek)
    }
}
