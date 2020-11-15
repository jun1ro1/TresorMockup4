//
//  AuthenticationManager.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/08.
//
// https://swift-ios.keicode.com/ios/touchid-faceid-auth.php
// https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
// https://medium.com/flawless-app-stories/ios-security-tutorial-part-2-c481036170ca

import Foundation
import SwiftUI

import LocalAuthentication

class AuthenticationManger {
    internal var authenticationView: AnyView = AnyView(EmptyView())
    
    private static var _manager: AuthenticationManger? = nil
    private static var _calledFirst = false
    
    static var shared: AuthenticationManger = {
        if _manager == nil {
            _manager     = AuthenticationManger()
            _calledFirst = true
        }
        return _manager!
    }()
    
    private static let DURATION = DispatchTimeInterval.seconds(30)
    
    private var mutex = NSLock()
    private var _authenticated = false
    fileprivate var authenticated: Bool {
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
                    .asyncAfter(deadline: .now() + AuthenticationManger.DURATION) {
                        J1Logger.shared.debug("authenticated time out=\(AuthenticationManger.DURATION)")
                        self.authenticated = false
                    }
            }
        }
    }
    
    init() {}
    
    // https://stackoverflow.com/questions/24158062/how-to-use-touch-id-sensor-in-ios-8/40612228
    func authentication(_ authenticatedBlock: @escaping (Bool) -> Void) -> Bool {
        var authError: NSError? = nil
        
        if AuthenticationManger._calledFirst {
            AuthenticationManger._calledFirst = false
            #if DEBUG_DELETE_KEYCHAIN
            try? CryptorSeed.delete()
            try? Validator.delete()
            #endif
        }
        
        guard Cryptor.isPrepared else {
            self.authenticationView = AnyView(RegisterPasswordView(authenticatedBlock: authenticatedBlock))
            return true
        }
        
        // already authenticated in 30 seconds
        let val = self.authenticated
        if val {
            J1Logger.shared.debug("authenticated=\(val)")
            authenticatedBlock(true)
            return false
        }
        assert(val == false, "self.authenticated is not false")
        
        do {
            let exists = try LocalPssword.doesExist()
            guard exists else {
                self.authenticationView = AnyView(EnterPasswordView(authenticatedBlock: authenticatedBlock))
                return true
            }
        }
        catch let error {
            J1Logger.shared.debug("LocalPssword.doesExist=\(error)")
            authenticatedBlock(false)
            return false
        }
        
        let context = LAContext()
        let reason  = "This app uses Touch ID / Facd ID to secure your data."
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason) { (success, error) in
                checkPassword: do {
                    guard success else {
                        J1Logger.shared.error("Authenticaion Error \(error!)")
                        break checkPassword
                    }
                    J1Logger.shared.debug("evaluatePolicy=success")
                    
                    var localPass: LocalPssword? = nil
                    do {
                        localPass = try LocalPssword.read()
                    }
                    catch let error {
                        J1Logger.shared.error("SecureStore read password Error \(error)")
                        break checkPassword
                    }
                    guard localPass != nil else {
                        J1Logger.shared.error("SecureStore read password failed")
                        break checkPassword
                    }
                    do {
                        try Cryptor.prepare(password: localPass!.password!)
                    }
                    catch let error {
                        J1Logger.shared.error("Cryptor.prepare error = \(error)")
                        break checkPassword
                    }
                    self.authenticated = true                    
                }
                let val = self.authenticated
                J1Logger.shared.debug("authenticated=\(val)")
                authenticatedBlock(self.authenticated)
            }
            return false
        }
        else {
            J1Logger.shared.info("Authentication with Biometrics is not enrolled \(authError!)")
            self.authenticationView = AnyView(EnterPasswordView(authenticatedBlock: authenticatedBlock))
            return true
        }
    }
}


// MARK: - PasswordField
struct PasswordField: View {
    @State   var text: String
    @Binding var password: String
    @Binding var showPassword: Bool
    var onCommit: () -> Void
    
    var body: some View {
        if self.showPassword {
            TextField(self.text,
                      text: self.$password,
                      onCommit: self.onCommit)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        else {
            SecureField(self.text,
                        text: self.$password,
                        onCommit: self.onCommit)
                .textContentType(.password)
                .keyboardType(.asciiCapable)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// MARK: - RegisterPasswordView
// https://stackoverflow.com/questions/58069516/how-can-i-have-two-alerts-on-one-view-in-swiftui
struct RegisterPasswordView: View {
    @State var authenticatedBlock: ((Bool) -> Void)?
    
    private enum ActiveAlert { case null, empty, unmatch }
    @State private var showPassword = false
    @State private var password1    = ""
    @State private var password2    = ""
    @State private var showAlert    = false
    @State private var activeAlert: ActiveAlert = .null
    
    var body: some View {
        VStack {
            Text("Register Your Password")
                .font(.title2)
                .padding()
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          onCommit: self.checkPassword)
                .padding()
            PasswordField(text: "Confirm Passowrd",
                          password: self.$password2,
                          showPassword: self.$showPassword,
                          onCommit: self.checkPassword)
                .padding()
            Button("Register", action: { self.checkPassword() })
                .disabled(self.password1 == "" || self.password2 == "")
                .padding()
        }
        .alert(isPresented: self.$showAlert) {
            switch self.activeAlert {
            case .unmatch:
                return Alert(title: Text("Not Match"),
                             message: Text("Please enter again"),
                             dismissButton: .default(Text("OK")))
            case .empty:
                return Alert(title: Text("Password Empty"),
                             message: Text("Please enter again"),
                             dismissButton: .default(Text("OK")))
            default:
                return Alert(title: Text("activeAlert error"),
                             message: Text(""))
            }
        }
    }
    
    func checkPassword() {
        guard self.password1 != "" && self.password2 != "" else {
            self.showAlert   = true
            self.activeAlert = .empty
            return
        }
        guard self.password1 == self.password2 else {
            self.showAlert   = true
            self.activeAlert = .unmatch
            return
        }
        
        do {
            try Cryptor.prepare(password: self.password1)
        }
        catch (let error) {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            guard self.authenticatedBlock != nil else {
                return
            }
            self.authenticatedBlock!(false)
            return
        }
        
        let passwordStore = LocalPssword(self.password1)
        do {
            try LocalPssword.write(passwordStore)
        }
        catch(let error) {
            J1Logger.shared.error("SecureStore write pass Error \(error)")
            guard self.authenticatedBlock != nil else {
                return
            }
            self.authenticatedBlock!(false)
            return
        }
        
        guard self.authenticatedBlock != nil else {
            return
        }
        self.authenticatedBlock!(true)
    }
}

struct EnterPasswordView: View {
    @State var authenticatedBlock: ((Bool) -> Void)?
    
    private enum ActiveAlert { case null, empty, unmatch }
    @State private var showPassword = false
    @State private var password1 = ""
    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .null
    
    
    var body: some View {
        VStack {
            Text("Enter Your Password")
                .font(.title2)
                .padding()
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          onCommit: self.checkPassword)
                .padding()
            Button("OK", action: { self.checkPassword() })
                .disabled(self.password1 == "")
                .padding()
        }
        .alert(isPresented: self.$showAlert) {
            switch self.activeAlert {
            case .unmatch:
                return Alert(title: Text("Not Match"),
                             message: Text("Please enter again"),
                             dismissButton: .default(Text("OK")))
            case .empty:
                return Alert(title: Text("Password Empty"),
                             message: Text("Please enter again"),
                             dismissButton: .default(Text("OK")))
            default:
                return Alert(title: Text("activeAlert error"),
                             message: Text(""))
            }
        }
    }
    
    func checkPassword() {
        guard self.password1 != "" else {
            self.showAlert   = true
            self.activeAlert = .empty
            return
        }
        
        do {
            try Cryptor.prepare(password: self.password1)
        }
        catch (let error) {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            guard self.authenticatedBlock != nil else {
                return
            }
            self.authenticatedBlock!(false)
            return
        }
        
        let passwordStore = LocalPssword(self.password1)
        do {
            try LocalPssword.write(passwordStore)
        }
        catch(let error) {
            J1Logger.shared.error("SecureStore write pass Error \(error)")
            guard self.authenticatedBlock != nil else {
                return
            }
            self.authenticatedBlock!(false)
            return
        }
        
        guard self.authenticatedBlock != nil else {
            return
        }
        self.authenticatedBlock!(true)
    }
}

struct PasswordView_Previews: PreviewProvider {
    @State private var sa: Bool = false
    
    static var previews: some View {
        Group {
            RegisterPasswordView()
            EnterPasswordView()
        }
    }
}

