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

class AuthenticationManger: ObservableObject {
    private static var _manager: AuthenticationManger? = nil
    
    static var shared: AuthenticationManger = {
        if _manager == nil {
            #if false // DEBUG_DELETE_KEYCHAIN
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
    
    @Published var view:       AnyView = AnyView(EmptyView())
    @Published var shouldShow: Bool    = false
    private    var authenticatedBlock: ((Bool) -> Void) = {_ in}
    
    func authenticate(authenticatedBlock: @escaping (Bool) -> Void = {_ in}) {
        self.authenticatedBlock = authenticatedBlock
        
        var authError: NSError? = nil
        
        guard Cryptor.isPrepared else {
            J1Logger.shared.debug("Cryptor is not prepared")
            self.view =
                AnyView(RegisterPasswordView(authenticatedBlock: self.authenticatedBlock))
            self.shouldShow = true
            return
        }
        
        // It has been already authenticated in 30 seconds
        let authenticated = AuthenticationManger.shared.authenticated
        if authenticated {
            J1Logger.shared.debug("already authenticated")
            AuthenticationManger.shared.authenticated = true
            self.authenticated = true
            self.authenticatedBlock(true)
            return
        }
        assert(authenticated == false, "self.authenticated is not false")
        
        do {
            guard try LocalPssword.doesExist() else {
                J1Logger.shared.debug("local password does not exist")
                self.view =
                    AnyView(RegisterPasswordView(authenticatedBlock: self.authenticatedBlock))
                self.shouldShow = true
                return
            }
        }
        catch let error {
            J1Logger.shared.debug("LocalPssword.doesExist=\(error)")
            AuthenticationManger.shared.authenticated = false
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
            J1Logger.shared.info("Authentication with Biometrics is not enrolled \(authError!)")
            self.view =
                AnyView(EnterPasswordView(authenticatedBlock: self.authenticatedBlock))
            self.shouldShow = true
        }
    }
    
}
// https://stackoverflow.com/questions/24158062/how-to-use-touch-id-sensor-in-ios-8/40612228

class PasswordChecker: ObservableObject {
    var authenticatedBlock: ((Bool) -> Void)?
    
    @Published var alertShow    = false
    @Published var alertTitle   = ""
    @Published var alertMessage = ""
    @Published var disabled     = false
    
    var password1: String = ""
    var password2: String = ""
    
    func check() {
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
            try Cryptor.prepare(password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            AuthenticationManger.shared.shouldShow    = false
            AuthenticationManger.shared.authenticated = false
            self.authenticatedBlock?(false)
            return
        }
        
        let passwordStore = LocalPssword(self.password1)
        do {
            try LocalPssword.write(passwordStore)
        }
        catch let error {
            J1Logger.shared.error("SecureStore write pass Error \(error)")
            AuthenticationManger.shared.shouldShow    = false
            AuthenticationManger.shared.authenticated = false
            self.authenticatedBlock?(false)
            return
        }
        
        AuthenticationManger.shared.shouldShow    = false
        AuthenticationManger.shared.authenticated = true
        self.authenticatedBlock?(true)
    }
}

// MARK: - RegisterPasswordView
// https://stackoverflow.com/questions/58069516/how-can-i-have-two-alerts-on-one-view-in-swiftui
struct RegisterPasswordView: View {
    var authenticatedBlock: ((Bool) -> Void)?
    
    @StateObject private var checker = PasswordChecker()
    
    @State private var showPassword = false
    @State private var password1    = ""
    @State private var password2    = ""
    
    func check() {
        self.checker.password1 = self.password1
        self.checker.password2 = self.password2
        self.checker.authenticatedBlock = self.authenticatedBlock
        self.checker.check()
    }
    
    var body: some View {
        let color = self.$checker.disabled.wrappedValue ? Color.gray : Color.black

        VStack {
            Text("Register a password for this App to protect your data.")
                .font(.title2)
                .padding()
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          disabled: self.$checker.disabled,
                          onCommit: self.check)
                .padding()
            PasswordField(text: "Confirm Passowrd",
                          password: self.$password2,
                          showPassword: self.$showPassword,
                          disabled: self.$checker.disabled,
                          onCommit: self.check)
                .padding()
            Button("Register",
                   action: self.check)
                .disabled(self.password1 == "" || self.password2 == "")
                .padding()
        }
        .foregroundColor(color)
        .alert(isPresented: self.$checker.alertShow) {
            Alert(title:   Text(self.checker.alertTitle),
                  message: Text(self.checker.alertMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
}


// https://developer.apple.com/forums/thread/650112
struct EnterPasswordView: View {
    var authenticatedBlock: ((Bool) -> Void)?

    @StateObject private var checker = PasswordChecker2()
    
    @State private var showPassword = false
    @State private var password1 = ""
    @State private var showAlert = false
    
    func check() {
        self.checker.password1 = self.password1
        self.checker.authenticatedBlock = self.authenticatedBlock
        self.checker.check()
    }

    var body: some View {
        let color = self.$checker.disabled.wrappedValue ? Color.secondary : Color.primary

        VStack {
            Text(self.checker.message)
                .font(.title2)
                .padding()
            Toggle("Show Password", isOn: self.$showPassword)
                .padding()
            PasswordField(text: "Enter Password",
                          password: self.$password1,
                          showPassword: self.$showPassword,
                          disabled: self.$checker.disabled,
                          onCommit: self.check)
                .foregroundColor(color)
                .padding()
            Button("OK", action: self.check)
                .disabled(self.password1 == "" || self.checker.disabled)
                .padding()
        }
        .alert(isPresented: self.$checker.alertShow) {
            Alert(title:   Text(self.checker.alertTitle),
                  message: Text(self.checker.alertMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
    
}

// MARK: - PasswordField
class PasswordChecker2: ObservableObject {
    var authenticatedBlock: ((Bool) -> Void)?
    
    @Published var alertShow    = false
    @Published var alertTitle   = ""
    @Published var alertMessage = ""
    @Published var message      = "Enter your password"
    @Published var disabled     = false
    
    var password1: String = ""
    private var retries = 0
    private let MAX_RETRIES = 6
    
    func check() {
        guard self.password1 != "" else {
            self.alertTitle   = "Password empty"
            self.alertMessage = "Please enter again"
            self.alertShow    = true
            return
        }
        
        retries += 1
        if retries > MAX_RETRIES {
            J1Logger.shared.error("retry count over = \(retries)")
            AuthenticationManger.shared.shouldShow    = false
            AuthenticationManger.shared.authenticated = false
            self.authenticatedBlock?(false)
        }
        if retries % 3 == 0 {
            let msg = {"Wait for \($0)" + ($0 > 1 ? " seconds." : " second.")}
            self.disabled = true
            var seconds = 20
            self.message = msg(seconds)
            _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                timer in
                self.message = msg(seconds)
                seconds -= 1
                if seconds < 0 {
                    timer.invalidate()
                    self.disabled = false
                    self.message = "Enter your password."
                }
            }
        }
        
        do {
            try Cryptor.prepare(password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            self.alertTitle   = "Incorrect password"
            self.alertMessage = "Please enter again"
            self.alertShow    = true
            return
        }
        
        AuthenticationManger.shared.shouldShow    = false
        AuthenticationManger.shared.authenticated = true
        self.authenticatedBlock?(true)
    }
}

struct PasswordField: View {
    @State   var text:         String
    @Binding var password:     String
    @Binding var showPassword: Bool
    @Binding var disabled:     Bool
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
                .disabled(self.disabled)
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
                .disabled(self.disabled)
        }
    }
}

// MARK: - Preview
struct PasswordView_Previews: PreviewProvider {
    @State private var sa: Bool = false
    
    static var previews: some View {
        Group {
            RegisterPasswordView()
            EnterPasswordView()
        }
    }
}

