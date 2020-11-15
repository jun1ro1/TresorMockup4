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
        case (.unexpected,       .unexpected),
             (.outOfRange,       .outOfRange),
             (.invalidCharacter, .invalidCharacter),
             (.wrongPassword,    .wrongPassword),
             (.notOpened,        .notOpened),
             (.alreadyOpened,    .alreadyOpened),
             (.notPrepared,      .notPrepared),
             (.SecItemBroken,    .SecItemBroken),
             (.timeOut,          .timeOut),
             (.sealError,        .sealError):
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

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) mark   =", mark as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) hshMark=", self.hashedMark! as NSData)
        #endif

        self.encryptedMark = try? mark.encrypt(using: key)
        guard self.encryptedMark != nil else {
            return nil
        }

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) encryptedMark=", self.encryptedMark! as NSData)
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

            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) hashedMark          =", hashedMark! as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) hashedDecryptedMark =", hashedDecryptedMark as NSData)
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) KEK   =", kek.data as NSData)
        #endif
        return kek
    }

    func prepare(password: String) throws {
        if self.isPrepared {
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
        }
        else {
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
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) salt  =", salt as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) kek   =", kek.data as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) cek   =", cek.data as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) cekEnc=", cekEnc.data as NSData)
            #endif
        }
    }


    func open(password: String, cryptor: Cryptor) throws -> SymmetricKey {
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
        var kek = try self.getKEK(password: password, seed: seed)
        defer{ kek.reset() }

        // get a CEK
        var cek: SymmetricKey
        do {
            cek = try SymmetricKey(data: cekEnc.data.decrypt(using: kek)) // excep
        } catch CryptoKit.CryptoKitError.authenticationFailure {
            throw CryptorError.wrongPassword
        } catch let error {
            throw error
        }
        defer{ cek.reset() }

        guard validator.validate(key: cek) == true else {
            throw CryptorError.wrongPassword
        }

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) cek   =", cek.data as NSData)
        #endif

        // check CEK
        guard validator.validate(key: cek) == true else {
            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) validate= false")
            #endif
            throw CryptorError.wrongPassword
        }

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
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) validate= false")
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) newkek    =", newkek.data as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) cek       =", cek.data as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) newkekEnc =", newcekEnc.data as NSData)
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk.data as NSData?) ?? "nil")
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk.data as NSData?) ?? "nil")
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk.data as NSData?) ?? "nil")
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
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk.data as NSData?) ?? "nil")
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

