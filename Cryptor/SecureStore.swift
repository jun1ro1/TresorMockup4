//
//  SecureStore.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/06.
//

import Foundation

// https://github.com/iosengineer/BMCredentials#RequirementsiCloudKeychain
// https://github.com/kishikawakatsumi/KeychainAccess
// https://stackoverflow.com/questions/41862997/ios-simulator-view-content-of-keychain

// MARK: -
internal class SecureStore {
    private var mutex: NSLock = NSLock()
    private var query: [String: Any]
    private var dateCreated:  Date?
    private var dateModified: Date?

    private init() {
        self.query = [:]
        self.dateCreated  = nil
        self.dateModified = nil
    }

    static var shared = SecureStore()

    private var queryString: String {
        return self.query.map { $0 + ":" + ($1 as AnyObject).description }.joined(separator: ", ")
    }
    
    private func errorString(_ status: OSStatus) -> String {
        let str = SecCopyErrorMessageString(status, nil) as String? ?? ""
        return String(status) + ":" + str
    }
    
    private func prepare(label: String, iCloud: Bool) {
        self.query = [
            kSecClass              as String: kSecClassGenericPassword,
            kSecAttrService        as String: Bundle.main.bundleIdentifier ?? "PasswortTresorTEST",
        ]
        self.query[ kSecAttrSynchronizable as String ] =
            iCloud ? kCFBooleanTrue! : kCFBooleanFalse!
        self.query[kSecAttrAccount as String] = label
    }
    
    func doseExist(label: String, iCloud: Bool = true) throws -> Bool {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        defer { self.mutex.unlock() }

        self.prepare(label: label, iCloud: iCloud)
        self.query[ kSecReturnData       as String] = kCFBooleanTrue
        self.query[ kSecMatchLimit       as String] = kSecMatchLimitOne
        self.query[ kSecReturnAttributes as String] = kCFBooleanTrue
        self.query[ kSecReturnData       as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(self.query as CFDictionary, UnsafeMutablePointer($0))
        }
        result = nil
        
        #if DEBUG
        J1Logger.shared.debug("label=\(label) query=[\(self.queryString)]" +
            " SecItemCopyMatching=\(self.errorString(status))")
        #endif

        switch status {
        case noErr:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw CryptorError.SecItemError(error: status)
        }
    }
    
    func read(label: String, iCloud: Bool = true) throws -> Data? {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        defer { self.mutex.unlock() }

        self.prepare(label: label, iCloud: iCloud)
        self.query[ kSecReturnData       as String] = kCFBooleanTrue
        self.query[ kSecMatchLimit       as String] = kSecMatchLimitOne
        self.query[ kSecReturnAttributes as String] = kCFBooleanTrue
        self.query[ kSecReturnData       as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(self.query as CFDictionary, UnsafeMutablePointer($0))
        }
        #if DEBUG
        J1Logger.shared.debug("label=\(label) query=[\(self.queryString)]" +
            " SecItemCopyMatching=\(self.errorString(status))")
        #endif

        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == noErr else {
            throw CryptorError.SecItemError(error: status)
        }
        guard let items = result as? Dictionary<String, AnyObject> else {
            throw CryptorError.SecItemBroken
        }
        guard let data = items[kSecValueData as String] as? Data else {
            throw CryptorError.SecItemBroken
        }

        #if DEBUG
//        SwiftyBeaver.debug("label=\(label) kSecValueData=\(data as NSData)")
        #endif

        self.dateCreated  = items[kSecAttrCreationDate     as String] as? Date
        self.dateModified = items[kSecAttrModificationDate as String] as? Date

        return data
    }

    func write(label: String, _ data: Data, iCloud: Bool = true) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        self.prepare(label: label, iCloud: iCloud)
        self.query[kSecValueData  as String] = data
        let status = SecItemAdd(self.query as CFDictionary, nil)
        self.mutex.unlock()

        #if DEBUG
        J1Logger.shared.debug("label=\(label) query=[\(self.queryString)]" +
            " SecItemAdd=\(self.errorString(status))")
        #endif

        guard status == noErr else {
            throw CryptorError.SecItemError(error: status)
        }
    }

    func update(label: String, _ data: Data, iCloud: Bool = true) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        self.prepare(label: label, iCloud: iCloud)
        let attr: [String: AnyObject] = [kSecValueData as String: data as AnyObject]
        let status = SecItemUpdate(self.query as CFDictionary, attr as CFDictionary)
        self.mutex.unlock()

        #if DEBUG
        J1Logger.shared.debug("label=\(label) query=[\(self.queryString)]" +
            " SecItemUpdate=\(self.errorString(status))")
        #endif

        guard status == noErr else {
            throw CryptorError.SecItemError(error: status)
        }
    }

    func delete(label: String, iCloud: Bool = true) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
//            SwiftyBeaver.error("label=\(label) mutex lock time out")
            throw CryptorError.timeOut
        }
        self.prepare(label: label, iCloud: iCloud)
        let status = SecItemDelete(self.query as NSDictionary)
        self.mutex.unlock()

        #if DEBUG
        J1Logger.shared.debug("label=\(label) query=[\(self.queryString)]" +
            " SecItemDelete=\(self.errorString(status))")
        #endif

        guard status == noErr || status == errSecItemNotFound else {
            throw CryptorError.SecItemError(error: status)
        }
    }

    var created : Date? {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.dateCreated
    }

    var modified : Date? {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.dateModified
    }
}
