//
//  PasswordPackage.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/04/15.
//

import Foundation

class PasswordBag: ObservableObject {
    @Published var passwordPlain:  String   = ""
    @Published var passwordCipher: String   = ""
    @Published var passwordHash:   Data     = Data()
    @Published var length:         Int16    = 0
    
    convenience init(password: Password) {
        self.init()
        self.passwordCipher = password.password     ?? ""
        self.passwordHash   = password.passwordHash ?? Data()
        self.length         = password.length
    }
    
    var isEmpty: Bool {
        return self.length == 0
    }
    
    var cipher: String {
        return self.passwordCipher
    }
    
    var plain: String {
        return self.passwordPlain
    }
    
    func clear() {
        self.passwordPlain  = ""
        self.passwordCipher = ""
        self.passwordHash   = Data()
        self.length         = 0
    }
    
    func set(plain: String) {
        self.passwordPlain  = plain
        self.passwordCipher = ""
        self.passwordHash   = plain.isEmpty ? Data() : (try? plain.hash()) ?? Data()
        self.length         = Int16(plain.count)
    }
    
    func set(cipher: String) {
        self.passwordPlain = ""
        self.passwordCipher = cipher
        self.passwordHash   = Data()
        self.length         = 0
    }
    
    func endecrypt(cryptor: CryptorUI) throws {
        switch (self.passwordPlain.isEmpty, self.passwordCipher.isEmpty) {
        case (true, false):
            self.passwordPlain = try cryptor.decrypt(cipher: self.passwordCipher)
            self.passwordHash  = try self.passwordPlain.hash()
        case (false, true):
            self.passwordCipher = try cryptor.encrypt(plain: self.passwordPlain)
            self.passwordHash   = try self.passwordPlain.hash()
        default:
            break
        }
        self.length        = Int16(self.passwordPlain.count)
    }
    
    func setTo(password: Password) {
        password.password     = self.passwordCipher
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
        
        site.password     = self.passwordCipher
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
