//
//  Cryptor.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/07.
//

import Foundation
import CryptoKit
import LocalAuthentication
import SwiftUI

import Introspect

/// The class to encrypt and decrypt a string or data
public class Cryptor: ObservableObject {
    /// A class variable for a singleton pattern
    static var shared: Cryptor = Cryptor()
    
    /// A calss variable to access the class `CryptorCore`
    internal static var core: CryptorCore = CryptorCore.shared
    
    @Published var view:       AnyView = AnyView(EmptyView())
    @Published var shouldShow: Bool    = false
    
    /// The instance variable to store a session key
    var key: SessionKey?
    
    /// Initializer
    init() {
        self.key = nil
    }
    
    private static let DURATION = DispatchTimeInterval.seconds(30)
    
    private var mutex = NSLock()
    private var _authenticated = false
    var authenticated: Bool {
        get {
            self.mutex.lock()
            let val = self._authenticated
            self.mutex.unlock()
            return val
        }
        set {
            self.mutex.lock()
            self._authenticated = newValue
            self.mutex.unlock()
            if newValue {
                DispatchQueue.global(qos: .background)
                    .asyncAfter(deadline: .now() + Cryptor.DURATION) {
                        J1Logger.shared.debug("authenticated time out=\(Cryptor.DURATION)")
                        self.authenticated = false
                    }
            }
        }
    }
    
    func open(password: String) throws {
        if Cryptor.core.isPrepared {
            try Cryptor.core.prepare(cryptor: self, password: password) // excep
        }
        else {
            try Cryptor.core.register(cryptor: self, password: password)
        }
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
    
    func open(authenticatedBlock: @escaping (Bool) -> Void = {_ in}) {
        guard Cryptor.core.isPrepared else {
            J1Logger.shared.debug("Cryptor is not prepared")
            self.view = AnyView(
                PasswordRegistrationView(message: "Register a password for this App to secure your data.",
                                         authenticatedBlock: authenticatedBlock,
                                         cryptor: self))
            self.shouldShow = true
            return
        }
        
        // It has been already authenticated in 30 seconds
        let authed = Cryptor.shared.authenticated
        if authed {
            J1Logger.shared.debug("already authenticated")
            Cryptor.shared.authenticated = true
            authenticatedBlock(true)
            return
        }
        assert(self.authenticated == false, "self.authenticated is not false")
        
        do {
            guard try LocalPassword.doesExist() else {
                J1Logger.shared.debug("local password does not exist")
                self.view = AnyView(
                    PasswordRegistrationView(message: "Register a password",
                                             authenticatedBlock: authenticatedBlock,
                                             cryptor: self))
                self.shouldShow = true
                return
            }
        }
        catch let error {
            J1Logger.shared.debug("LocalPssword.doesExist=\(error)")
            self.view = AnyView(
                PasswordRegistrationView(message: "Stored local password does not exist, then register a password.",
                                         authenticatedBlock: authenticatedBlock,
                                         cryptor: self))
            self.shouldShow = true
            return
        }
        
        let context = LAContext()
        let reason  = "This app uses Touch ID / Facd ID to secure your data."
        var authError: NSError? = nil
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason) { (success, error) in
                DispatchQueue.main.async {
                    guard success else {
                        J1Logger.shared.error("Authenticaion Error \(error!)")
                        self.view = AnyView(
                            PasswordEntryView(message: "Biometrics authentication failed, please enter a password for this app.",
                                              authenticatedBlock: authenticatedBlock,
                                              cryptor: self))
                        self.shouldShow = true
                        return
                    }
                    J1Logger.shared.debug("evaluatePolicy=success")
                    
                    var localPass: LocalPassword? = nil
                    do {
                        localPass = try LocalPassword.read()
                    }
                    catch let error {
                        J1Logger.shared.error("SecureStore read password Error \(error)")
                        self.view = AnyView(
                            PasswordEntryView(message: "Cannot read a local password, please enter a password.",
                                              authenticatedBlock: authenticatedBlock,
                                              cryptor: self))
                        self.shouldShow = true
                        return
                    }
                    guard localPass != nil else {
                        J1Logger.shared.error("SecureStore read password failed")
                        self.view = AnyView(
                            PasswordEntryView(message: "A local password is nil, please enter a password.",
                                              authenticatedBlock: authenticatedBlock,
                                              cryptor: self))
                        self.shouldShow = true
                        return
                    }
                    do {
                        try Cryptor.core.prepare(cryptor: self, password: localPass!.password!)
                    }
                    catch let error {
                        J1Logger.shared.error("Cryptor.prepare error = \(error)")
                        self.view = AnyView(
                            PasswordEntryView(message: "A local password is incorrect, please enter a password.",
                                              authenticatedBlock: authenticatedBlock,
                                              cryptor: self))
                        self.shouldShow = true
                        return
                    }
                    J1Logger.shared.debug("authenticated by biometrics")
                    Cryptor.shared.authenticated = true
                    authenticatedBlock(true)
                }
            }
        }
        else {
            J1Logger.shared.info("Authentication with Biometrics is not enrolled \(authError!)")
            self.view = AnyView(
                PasswordEntryView(message: "Enter a password for this app.",
                                  authenticatedBlock: authenticatedBlock,
                                  cryptor: self))
            self.shouldShow = true
        }
    } // open
}


// MARK: - PasswordRegistrationView
// https://stackoverflow.com/questions/58069516/how-can-i-have-two-alerts-on-one-view-in-swiftui
struct PasswordRegistrationView: View {
    var message: String
    var authenticatedBlock: ((Bool) -> Void)?
    var cryptor: Cryptor
    
    @State private var showPassword = false
    @State private var password1    = ""
    @State private var password2    = ""
    
    @State private var alertShow    = false
    @State private var alertTitle   = ""
    @State private var alertMessage = ""
    @State private var disabled     = false
    
    private let title = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    
    func validate() {
        guard self.password1 != "" && self.password2 != "" else {
            self.alertTitle   = "Password empty"
            self.alertMessage = "Please register again"
            self.alertShow    = true
            return
        }
        guard self.password1 == self.password2 else {
            self.alertTitle   = "Password unmatch"
            self.alertMessage = "Please register again"
            self.alertShow    = true
            return
        }
        
        do {
            try Cryptor.core.prepare(cryptor: cryptor, password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            Cryptor.shared.shouldShow    = false
            Cryptor.shared.authenticated = false
            self.authenticatedBlock?(false)
            return
        }
        
        let passwordStore = LocalPassword(self.password1)
        do {
            try LocalPassword.write(passwordStore)
        }
        catch let error {
            J1Logger.shared.error("SecureStore write pass Error \(error)")
            Cryptor.shared.shouldShow    = false
            Cryptor.shared.authenticated = false
            self.authenticatedBlock?(false)
            return
        }
        
        Cryptor.shared.shouldShow    = false
        Cryptor.shared.authenticated = true
        self.authenticatedBlock?(true)
    }
    
    var body: some View {
        let color = self.disabled ? Color.gray : Color.black
        
        VStack {
            Text(title)
                .font(.title)
                .padding()
            Text(self.message)
                .font(.title2)
                .padding()
                .foregroundColor(color)
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
                .foregroundColor(color)
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          disabled: self.$disabled,
                          onCommit: self.validate)
                .padding()
            PasswordField(text: "Confirm Passowrd",
                          password: self.$password2,
                          showPassword: self.$showPassword,
                          disabled: self.$disabled,
                          onCommit: self.validate)
                .padding()
            Button("Register",
                   action: self.validate)
                .disabled(self.password1 == "" || self.password2 == "")
                .padding()
        }
        .alert(isPresented: self.$alertShow) {
            Alert(title:   Text(self.alertTitle),
                  message: Text(self.alertMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
}


// MARK: - PasswordEntryView
struct PasswordEntryView: View {
    @State var message: String
    var authenticatedBlock: ((Bool) -> Void)?
    var cryptor: Cryptor
    
    @State private var showPassword = false
    @State private var password1 = ""
    
    @State private var alertShow    = false
    @State private var alertTitle   = ""
    @State private var alertMessage = ""
    @State private var disabled     = false
    
    private let MAX_RETRIES    = 6
    @State private var retries = 0
    @State private var seconds = 0
    
    @State private var messageSaved = ""
    
    private let title = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    
    func msg(_ sec: Int) -> String {
        return "Wait for \(String(sec))" + (sec > 1 ? " seconds." : " second.")
    }
    
    func validate() {
        guard self.password1 != "" else {
            self.alertTitle   = "Password empty"
            self.alertMessage = "Please enter again"
            self.alertShow    = true
            return
        }
        
        self.retries += 1
        guard self.retries <= MAX_RETRIES else {
            J1Logger.shared.error("retry count over = \(retries)")
            Cryptor.shared.shouldShow    = false
            Cryptor.shared.authenticated = false
            self.authenticatedBlock?(false)
            return
        }
        
        if self.retries % 3 == 0 {
            self.disabled = true
            self.seconds = 20
            self.messageSaved = self.message
            self.message = self.msg(self.seconds)
            _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                timer in
                self.message = self.msg(self.seconds)
                self.seconds -= 1
                if self.seconds < 0 {
                    timer.invalidate()
                    self.disabled = false
                    self.message = self.messageSaved
                }
            }
        }
        
        do {
            try Cryptor.core.prepare(cryptor: cryptor, password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            self.alertTitle   = "Incorrect password"
            self.alertMessage = "Please enter again"
            self.alertShow    = true
            return
        }
        
        Cryptor.shared.shouldShow    = false
        Cryptor.shared.authenticated = true
        self.authenticatedBlock?(true)
    }
    
    var body: some View {
        let color = self.disabled ? Color.secondary : Color.primary
        
        VStack {
            Text(title)
                .font(.title)
                .padding()
            Text(self.message)
                .font(.title2)
                .padding()
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          disabled: self.$disabled,
                          onCommit: self.validate)
                .foregroundColor(color)
                .padding()
                .introspectTextField { textField in
                    textField.becomeFirstResponder()
                }
            Button("OK", action: self.validate)
                .disabled(self.password1 == "" || self.disabled)
                .padding()
        }
        .alert(isPresented: self.$alertShow) {
            Alert(title:   Text(self.alertTitle),
                  message: Text(self.alertMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
}


// MARK: - PasswordField
struct PasswordField: View {
    @State   var text:         String
    @Binding var password:     String
    @Binding var showPassword: Bool
    @Binding var disabled:     Bool
    var onCommit: () -> Void
    
    var body: some View {
        Group {
            if self.showPassword {
                TextField(self.text,
                          text: self.$password,
                          onCommit: self.onCommit)
            }
            else {
                SecureField(self.text,
                            text: self.$password,
                            onCommit: self.onCommit)
            }
        }
        .textContentType(.password)
        .keyboardType(.asciiCapable)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .disabled(self.disabled)
        
    }
}

// MARK: - Previews
struct PasswordView_Previews: PreviewProvider {
    @State private var sa: Bool = false
    
    static var previews: some View {
        Group {
            PasswordRegistrationView(message: "Registration View", cryptor: Cryptor())
            PasswordEntryView(message: "Password Entry View", cryptor: Cryptor())
        }
    }
}

