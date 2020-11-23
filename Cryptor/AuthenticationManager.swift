//
//  AuthenticationHandler.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/15.
//
// https://stackoverflow.com/questions/60297637/biometric-authentication-evaluation-with-swiftui
// https://swiftui-lab.com/state-changes/
// https://stackoverflow.com/questions/60155947/swiftui-usage-of-toggles-console-logs-invalid-mode-kcfrunloopcommonmodes

import Foundation
import SwiftUI

import LocalAuthentication

class AuthenticationManger {
    private static var _manager: AuthenticationManger? = nil
    
    static var shared: AuthenticationManger = {
        if _manager == nil {
            #if true // DEBUG_DELETE_KEYCHAIN
            try? CryptorSeed.delete()
            try? Validator.delete()
            try? LocalPssword.delete()
            #endif
            _manager     = AuthenticationManger()
        }
        return _manager!
    }()
    
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
                    .asyncAfter(deadline: .now() + AuthenticationManger.DURATION) {
                        J1Logger.shared.debug("authenticated time out=\(AuthenticationManger.DURATION)")
                        self.authenticated = false
                    }
            }
        }
    }
    
    init() {}
}
// https://stackoverflow.com/questions/24158062/how-to-use-touch-id-sensor-in-ios-8/40612228

class AuthenticationHandler: ObservableObject {
    @Published var view: AnyView = AnyView(EmptyView())
    @Published var shouldShow: Bool = false
    @Published var authenticated: Bool = false
    private    var authenticatedBlock: ((Bool) -> Void) = {_ in}
    
    init() {}
    
    init(_ authenticatedBlock: @escaping (Bool) -> Void) {
        self.authenticatedBlock = authenticatedBlock
    }
    
    internal func authenticate() {
        var authError: NSError? = nil
        
        guard Cryptor.isPrepared else {
            J1Logger.shared.debug("Cryptor is not prepared")
            self.view =
                AnyView(RegisterPasswordView(handler: self,
                                             authenticatedBlock: self.authenticatedBlock))
            self.shouldShow = true
            return
        }
        
        // It has been already authenticated in 30 seconds
        let authenticated = AuthenticationManger.shared.authenticated
        if authenticated {
            J1Logger.shared.debug("already authenticated")
            self.authenticated = true
            self.authenticatedBlock(true)
            return
        }
        assert(authenticated == false, "self.authenticated is not false")
        
        do {
            guard try LocalPssword.doesExist() else {
                J1Logger.shared.debug("local password does not exist")
                self.view =
                    AnyView(RegisterPasswordView(handler: self,
                                                 authenticatedBlock: self.authenticatedBlock))
                self.shouldShow = true
                return
            }
        }
        catch let error {
            J1Logger.shared.debug("LocalPssword.doesExist=\(error)")
            self.authenticated = false
            self.authenticatedBlock(false)
            return
        }
        
        let context = LAContext()
        let reason  = "This app uses Touch ID / Facd ID to secure your data."
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason) { (success, error) in
                DispatchQueue.main.async {
                    checkPassword: do {
                        guard success else {                        J1Logger.shared.error("Authenticaion Error \(error!)")
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
                        AuthenticationManger.shared.authenticated = true
                    }
                    let val = AuthenticationManger.shared.authenticated
                    J1Logger.shared.debug("authenticated=\(val)")
                    self.authenticated = val
                    self.authenticatedBlock(val)
                }
            }
        }
        else {
            DispatchQueue.main.async {
                J1Logger.shared.info("Authentication with Biometrics is not enrolled \(authError!)")
                self.view =
                    AnyView(EnterPasswordView(handler: self, authenticatedBlock: self.authenticatedBlock))
                self.shouldShow = true
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
        var handler: AuthenticationHandler? = nil
        @State var authenticatedBlock: ((Bool) -> Void)?
        
        private enum ActiveAlert { case null, empty, unmatch }
        @State private var showPassword = false
        @State private var password1    = ""
        @State private var password2    = ""
        @State private var showAlert    = false
        @State private var activeAlert: ActiveAlert = .null
        
        var body: some View {
            VStack {
                Text("Register a password for this App to protect your data.")
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
            catch let error {
                J1Logger.shared.error("Cryptor.prepare error = \(error)")
                handler?.shouldShow = false
                self.handler?.authenticated = false
                self.authenticatedBlock?(false)
                return
            }
            
            let passwordStore = LocalPssword(self.password1)
            do {
                try LocalPssword.write(passwordStore)
            }
            catch let error {
                J1Logger.shared.error("SecureStore write pass Error \(error)")
                handler?.shouldShow = false
                self.handler?.authenticated = false
                self.authenticatedBlock?(false)
                return
            }
            
            handler?.shouldShow = false
            self.handler?.authenticated = true
            self.authenticatedBlock?(true)
        }
    }
    
    // https://developer.apple.com/forums/thread/650112
    struct EnterPasswordView: View {
        var handler: AuthenticationHandler? = nil
        var authenticatedBlock: ((Bool) -> Void)?
        
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
            catch let error {
                J1Logger.shared.error("Cryptor.prepare error = \(error)")
                handler?.shouldShow = false
                self.handler?.authenticated = false
                self.authenticatedBlock?(false)
                return
            }
            
            handler?.shouldShow = false
            self.handler?.authenticated = true
            self.authenticatedBlock?(true)
        }
    }
}

struct PasswordView_Previews: PreviewProvider {
    @State private var sa: Bool = false
    
    static var previews: some View {
        Group {
            AuthenticationHandler.RegisterPasswordView()
            AuthenticationHandler.EnterPasswordView()
        }
    }
}

