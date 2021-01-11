//
//  CryptorCore.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/03.
//

import Foundation
import CryptoKit
import CommonCrypto

public enum CryptorError: Error {
    case unexpected
    case outOfRange
    case invalidCharacter
    case wrongPassword
    case notOpened
    case alreadyOpened
    case notPrepared
    case alreadyRegistered
    case SecItemBroken
    case timeOut
    case sealError
    case CryptoKitError(error: CryptoKitError)
    case SecItemError(error: OSStatus)
}

extension CryptorError: LocalizedError {
    /// Returns a description of the error.
    public var errorDescription: String?  {
        switch self {
        case .unexpected:
            return "Unexpected Error"
        case .outOfRange:
            return "Out of Range"
        case .invalidCharacter:
            return "Invalid Character"
        case .wrongPassword:
            return "Wrong Password"
        case .notOpened:
            return "Cryptor is not Opened"
        case .alreadyOpened:
            return "Cryptor is already Opened"
        case .notPrepared:
            return "Prepare is not called"
        case .alreadyRegistered:
            return "Register is called twice"
        case .SecItemBroken:
            return "SecItem is broken"
        case .timeOut:
            return "Time Out to acquire a lock"
        case .sealError:
            return "AES.GCM.seal error"
        case .CryptoKitError(let error):
            return "CryptokitError(\(error)"
        case .SecItemError(let error):
            return "SecItem Error(\(error))"
        }
    }
}

// https://stackoverflow.com/questions/39972512/cannot-invoke-xctassertequal-with-an-argument-list-errortype-xmpperror
extension CryptorError: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// - Parameters:
    ///   - lhs: A left hand side expression.
    ///   - rhs: A right hand side expression.
    /// - Returns: `True` if `lhs` equals `rhs`, otherwise `false`.
    public static func == (lhs: CryptorError, rhs: CryptorError) -> Bool {
        switch (lhs, rhs) {
        case (.unexpected,         .unexpected),
             (.outOfRange,         .outOfRange),
             (.invalidCharacter,   .invalidCharacter),
             (.wrongPassword,      .wrongPassword),
             (.notOpened,          .notOpened),
             (.alreadyRegistered,  .alreadyRegistered),
             (.alreadyOpened,      .alreadyOpened),
             (.notPrepared,        .notPrepared),
             (.SecItemBroken,      .SecItemBroken),
             (.timeOut,            .timeOut),
             (.sealError,          .sealError):
            return true
        case (.CryptoKitError(let error1), .CryptoKitError(let error2)):
            return error1.localizedDescription  == error2.localizedDescription
        case (.SecItemError(let error1), .SecItemError(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}

// MARK: -
private struct Session {
    var cryptor: Cryptor
    var itk:     SymmetricKey
    // Inter key: the KEK(Key kncryption Key) encrypted using SEK(Session Key)
    
    init(cryptor: Cryptor, itk: SymmetricKey) {
        self.cryptor = cryptor
        self.itk  = itk
    }
}


// MARK: -
internal class CryptorCore {
    // constants
    public static let MAX_PASSWORD_LENGTH = 1000
    
    // instance variables
    private var sessions: [Int: Session] = [:]
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
    
    private init() {
    }
    
    // MARK: - methods
    private func getKEK(password: String, seed: CryptorSeed) throws -> SymmetricKey {
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
        
        let prk: SymmetricKey = SymmetricKey(data: binPASS.hash())
        
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        let kek = HKDF<SHA256>.deriveKey(inputKeyMaterial: prk, salt: salt, outputByteCount: 32)                
        self.mutex.unlock()
        #if DEBUG
        J1Logger.shared.debug("KEK=\(kek.data as NSData)")
        #endif
        return kek
    }
    
    func prepare(password: String) throws -> SymmetricKey {
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
        
        return kek
    }
    
    
    func register(password: String) throws -> SymmetricKey {
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
        var seed = CryptorSeed(version: "2", salt: salt)
        
        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: password, seed: seed)
        defer { kek.reset() }
        
        // create a CEK
        var cek: SymmetricKey = SymmetricKey(size: .bits256)
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
        
        #if DEBUG
        J1Logger.shared.debug("salt=\(salt as NSData)")
        J1Logger.shared.debug("kek=\(kek.data as NSData)")
        J1Logger.shared.debug("cek=\(cek.data as NSData)")
        J1Logger.shared.debug("cekEnc=\(cekEnc.data as NSData)")
        #endif
        
        return kek
    }
    
    
    func open(password: String, cryptor: Cryptor) throws -> SymmetricKey {
        var kek = try self.prepare(password: password)
        defer { kek.reset() }
        
        var sek: SymmetricKey = SymmetricKey(size: .bits256)
        defer { sek.reset() }
        
        var itk: SymmetricKey = try SymmetricKey(data: kek.data.encrypt(using: sek))
        defer { itk.reset() }
        
        let session = Session(cryptor: cryptor, itk: itk)
        self.mutex.lock()
        self.sessions[ObjectIdentifier(cryptor).hashValue] = session
        self.mutex.unlock()
        
        return sek
    }
    
    
    func close(cryptor: Cryptor) throws {
        self.mutex.lock()
        let result = self.sessions.removeValue(forKey: ObjectIdentifier(cryptor).hashValue)
        self.mutex.unlock()
        
        guard result != nil else {
            throw CryptorError.notOpened
        }
    }
    
    func closeAll() throws {
        var errors = 0
        while true {
            self.mutex.lock()
            let before = self.sessions.count
            let session = self.sessions.first?.value
            self.mutex.unlock()
            
            guard session != nil else {
                break
            }
            try self.close(cryptor: session!.cryptor)
            
            self.mutex.lock()
            let after = self.sessions.count
            self.mutex.unlock()
            if before >= after {
                errors += 1
            }
            guard errors < 100 else {
                throw CryptorError.unexpected
            }
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
        
        #if DEBUG
        J1Logger.shared.debug("newkek   =\(newkek.data)")
        J1Logger.shared.debug("cek      =\(cek.data)")
        J1Logger.shared.debug("newkekEnc=\(newcekEnc.data)")
        #endif
    }
    
    func encrypt(cryptor: Cryptor, plain: Data) throws -> Data {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()
        
        #if DEBUG
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
        
        var cek: SymmetricKey = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer { cek.reset() }
        
        return try plain.encrypt(using: cek)
    }
    
    func decrypt(cryptor: Cryptor, cipher: Data) throws -> Data {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()
        
        #if DEBUG
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
        
        var cek: SymmetricKey = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer { cek.reset() }
        
        return try cipher.decrypt(using: cek)
    }
    
    func encrypt(cryptor: Cryptor, plain: String) throws -> String {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()
        
        #if DEBUG
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
        
        var cek: SymmetricKey = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer { cek.reset() }
        
        return try plain.encrypt(using: cek)
    }
    
    func decrypt(cryptor: Cryptor, cipher: String) throws -> String {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()
        
        #if DEBUG
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
        
        var cek: SymmetricKey = try SymmetricKey(data: cekEnc.data.decrypt(using: kek))
        defer { cek.reset() }
        
        return try cipher.decrypt(using: cek)
    }
}
