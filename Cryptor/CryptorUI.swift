//
//  CryptorUI.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/01/23.
//

import Foundation
import LocalAuthentication
import SwiftUI

struct CryptorUIKey: EnvironmentKey {
    typealias Value = CryptorUI
    
    static var defaultValue: Value = CryptorUI()
}

extension EnvironmentValues {
    var cryptor: CryptorUI {
        get {
            return self[CryptorUIKey.self]
        }
        set {
            self[CryptorUIKey.self] = newValue
        }
    }
}

public class CryptorUI: Cryptor, ObservableObject {
    
    @Published var view:          AnyView  = AnyView(EmptyView())
    @Published var shouldShow:    Bool     = false
    @Published var opened:        Bool     = false
    
    private var authenticated_private: Bool   = false
    private var timer:                 Timer? = nil
    private var duration: Int                 = 0
    
    init(name: String = "", duration: Int = 0) {
        super.init(name: name)
        self.duration = min(max(duration, 0), 60 * 60) // max 60 minutes
    }
    
    deinit {
        J1Logger.shared.debug("[\(self.name)]")
    }
    
    fileprivate var authenticated: Bool {
        get {
            return self.authenticated_private
        }
        set {
            if let t = self.timer, t.isValid {
                J1Logger.shared.debug("[\(name)] authenticated timer canceled")
                t.invalidate()
            }
            self.authenticated_private = newValue
            self.opened = newValue
            
            if newValue {
                if self.duration > 0 {
                    self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.duration),
                                                      repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        J1Logger.shared.debug("[\(self.name)] authenticated time out=\(self.duration)")
                        self.authenticated = false // recursive call
                    }
                }
            }
        }
    }
    
    private func enterLocalPassword() throws -> Bool {
        let localPass: LocalPassword? = try LocalPassword.read()
        guard localPass != nil else { return false }
        guard localPass?.password != nil else { return false }

        try self.open(password: localPass!.password!)
        return true
    }
    
    func open(_ block: ((Bool?) -> Void)? = nil) {
        guard Cryptor.core.isPrepared else {
            J1Logger.shared.debug("Cryptor is not prepared")
            self.view = AnyView(
                PasswordRegistrationView(message: "Register a master password for this App to secure your data.",
                                         block: block, cryptorUI: self))
            self.shouldShow = true
            return
        }
        
        do {
            guard try LocalPassword.doesExist() else {
                J1Logger.shared.debug("local password does not exist")
                self.view = AnyView(
                    PasswordRegistrationView(message: "Register a master password",
                                             block: block, cryptorUI: self))
                self.shouldShow = true
                return
            }
        } catch let error {
            J1Logger.shared.debug("LocalPssword.doesExist=\(error)")
            self.view = AnyView(
                PasswordRegistrationView(
                    message: "Stored local password does not exist, please register a master password.",
                    block: block, cryptorUI: self))
            self.shouldShow = true
            return
        }
        
        // It has been already authenticated in 30 seconds
        let authenticated = self.authenticated
        if authenticated {
            J1Logger.shared.debug("already authenticated")
            do {
                guard try self.enterLocalPassword() else {
                    J1Logger.shared.error("SecureStore read password failed")
                    self.view = AnyView(
                        PasswordRegistrationView(
                            message: "A local password is not found, please register a master password.",
                            block: block, cryptorUI: self))
                    self.shouldShow = true
                    return
                }
            } catch let error {
                J1Logger.shared.error("enterLocalPassowrd Error \(error)")
                self.view = AnyView(
                    PasswordEntryView(
                        message: "A local password is incorrect, please enter a master password.",
                        block: block, cryptorUI: self))
                self.shouldShow = true
                return
            }
            self.authenticated = true
            block?(true)
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
                            PasswordEntryView(
                                message: "Biometrics authentication failed, please enter a master password for this app.",
                                block: block, cryptorUI: self))
                        self.shouldShow = true
                        return
                    }
                    J1Logger.shared.debug("evaluatePolicy=success")
                    
                    do {
                        guard try self.enterLocalPassword() else {
                            J1Logger.shared.error("SecureStore read password failed")
                            self.view = AnyView(
                                PasswordRegistrationView(
                                    message: "A local password is not found, please register a master password.",
                                    block: block, cryptorUI: self))
                            self.shouldShow = true
                            return
                        }
                    } catch let error {
                        J1Logger.shared.error("enterLocalPassowrd Error \(error)")
                        self.view = AnyView(
                            PasswordEntryView(
                                message: "A local password is incorrect, please enter a master password.",
                                block: block, cryptorUI: self))
                        self.shouldShow = true
                        return
                    }
                    
                    J1Logger.shared.debug("authenticated by biometrics")
                    self.authenticated = true
                    block?(true)
                }
            }
        }
        else {
            J1Logger.shared.info("Authentication with Biometrics is not enrolled \(authError!)")
            self.view = AnyView(
                PasswordEntryView(message: "Enter a master password for this app.",
                                  block: block, cryptorUI: self))
            self.shouldShow = true
        }
    } // open
    
    func close(_ block: ((Bool?) -> Void)? = nil) {
        block?(false)
        self.opened = false
        try? super.close()
    }
    
    func toggle(_ block: ((Bool?) -> Void)? = nil) {
        if self.opened {
            self.close(block)
        }
        else {
            self.open(block)
        }
    }
}

// MARK: - PasswordRegistrationView
// https://stackoverflow.com/questions/58069516/how-can-i-have-two-alerts-on-one-view-in-swiftui
struct PasswordRegistrationView: View {
    @State var message:   String
    var block: ((Bool?) -> Void)?
    var cryptorUI: CryptorUI
    
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
//            try Cryptor.core.register(cryptor: self.cryptorUI, password: self.password1)
            try self.cryptorUI.open(password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            self.cryptorUI.shouldShow    = false
            self.cryptorUI.authenticated = false
            self.block?(nil)
            return
        }
        
        let passwordStore = LocalPassword(self.password1)
        do {
            try LocalPassword.write(passwordStore)
        }
        catch let error {
            J1Logger.shared.error("SecureStore write pass Error \(error)")
            self.cryptorUI.shouldShow    = false
            self.cryptorUI.authenticated = false
            self.block?(nil)
            return
        }
        
        // password regstration success
        self.cryptorUI.shouldShow    = false
        self.cryptorUI.authenticated = true
        self.block?(true)
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
            HStack {
                PasswordField(text: "Enter Password",
                              password: self.$password1,
                              showPassword: self.$showPassword,
                              disabled: self.$disabled,
                              onCommit: self.validate)
                    .introspectTextField { textField in
                        textField.becomeFirstResponder()
                    }
                Spacer()
                Button {
                    self.showPassword.toggle()
                } label: {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            HStack {
                PasswordField(text: "Confirm Passowrd",
                              password: self.$password2,
                              showPassword: self.$showPassword,
                              disabled: self.$disabled,
                              onCommit: self.validate)
                Spacer()
                Button {
                    self.showPassword.toggle()
                } label: {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
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
    @State var message:   String
    var block: ((Bool?) -> Void)?
    var cryptorUI: CryptorUI
    
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
            self.cryptorUI.shouldShow    = false
            self.cryptorUI.authenticated = false
            self.block?(nil)
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
//            try Cryptor.core.prepare(cryptor: self.cryptorUI, password: self.password1)
            try self.cryptorUI.open(password: self.password1)
        }
        catch let error {
            J1Logger.shared.error("Cryptor.prepare error = \(error)")
            self.alertTitle   = "Incorrect password"
            self.alertMessage = "Please enter again"
            self.alertShow    = true
            return
        }
        
        self.cryptorUI.shouldShow    = false
        self.cryptorUI.authenticated = true
        self.block?(true)
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
            HStack {
                PasswordField(text: "Enter Password",
                              password: self.$password1,
                              showPassword: self.$showPassword,
                              disabled: self.$disabled,
                              onCommit: self.validate)
                    .foregroundColor(color)
                    .introspectTextField { textField in
                        textField.becomeFirstResponder()
                    }
                Spacer()
                Button {
                    self.showPassword.toggle()
                } label: {
                    Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
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
            PasswordRegistrationView(message: "Registration View", cryptorUI: CryptorUI())
            PasswordEntryView(message: "Password Entry View", cryptorUI: CryptorUI())
        }
    }
}
