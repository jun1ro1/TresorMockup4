//
//  PasswordPackage.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/04/15.
//

import Foundation

class PasswordProxy: ObservableObject {
    @Published var plainPassword:  String   = ""
    
    private var cipherPassword: String   = ""
    private var passwordHash:   Data     = Data()
    private var length:         Int16    = 0
    
    convenience init(password: Password) {
        self.init()
        self.cipherPassword = password.password     ?? ""
        self.passwordHash   = password.passwordHash ?? Data()
        self.length         = password.length
    }
    
    convenience init(site: Site) {
        self.init()
        self.cipherPassword = site.password     ?? ""
        self.passwordHash   = site.passwordHash ?? Data()
        self.length         = site.length
    }

    var isEmpty: Bool {
        return self.length == 0
    }
    
    var cipher: String {
        get {
            return self.cipherPassword
        }
        set {
            self.plainPassword = ""
            self.cipherPassword = newValue
            self.passwordHash   = Data()
            self.length         = 0
        }
    }
    
    var plain: String {
        get {
            return self.plainPassword
        }
        set {
            self.plainPassword  = newValue
            self.cipherPassword = ""
            self.passwordHash   = self.plainPassword.isEmpty ?
                Data() : (try? self.plainPassword.hash()) ?? Data()
            self.length         = Int16(self.plainPassword.count)
        }
    }
    
    func clear() {
        self.plainPassword  = ""
        self.cipherPassword = ""
        self.passwordHash   = Data()
        self.length         = 0
    }
    
    func endecrypt(cryptor: CryptorUI) throws {
        switch (self.plainPassword.isEmpty, self.cipherPassword.isEmpty) {
        case (true, false):
            self.plainPassword = try cryptor.decrypt(cipher: self.cipherPassword)
            self.passwordHash  = try self.plainPassword.hash()
        case (false, true):
            self.cipherPassword = try cryptor.encrypt(plain: self.plainPassword)
            self.passwordHash   = try self.plainPassword.hash()
        default:
            break
        }
        self.length        = Int16(self.plainPassword.count)
    }
    
   func setTo(password: Password) {
        password.password     = self.cipherPassword
        password.passwordHash = self.passwordHash
        password.length       = self.length
    }
    
    func setTo(site: Site) {
        guard let viewContext = site.managedObjectContext else { return }
        let passwords = (site.passwords?.allObjects as? [Password] ?? [])
            .sorted { (x, y) -> Bool in
                let xc = x.createdAt ?? Date(timeIntervalSince1970: 0)
                let yc = y.createdAt ?? Date(timeIntervalSince1970: 0)
                return xc < yc
            }
        
        // save old password
        if let oldPassHash = site.passwordHash,
           passwords.first(where: { $0.passwordHash == oldPassHash }) == nil {
            let oldPassword = Password(context: viewContext)
            self.setTo(password: oldPassword)
            oldPassword.site = site
            site.addToPasswords(oldPassword)
        }
        
        site.password     = self.cipherPassword
        site.passwordHash = self.passwordHash
        site.length       = self.length
        
        if let password = passwords.first(where: { $0.passwordHash == self.passwordHash }) {
            self.setTo(password: password)
            password.toCurrent()
        } else {
            let newPassword = Password(context: viewContext)
            self.setTo(password: newPassword)
            newPassword.site = site
            site.addToPasswords(newPassword)
            newPassword.toCurrent()
        }
    }
}
