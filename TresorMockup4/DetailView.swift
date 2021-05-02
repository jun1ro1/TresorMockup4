//
//  DetailView.swift
//  TresorMockup4o
//
//  Created by OKU Junichirou on 2020/11/23.
//
// https://developer.apple.com/forums/thread/128366
// https://capibara1969.com/2625/
// https://capibara1969.com/2303/
// https://stackoverflow.com/questions/57947581/why-buttons-dont-work-when-embedded-in-a-swiftui-form
// https://stackoverflow.com/questions/57518874/swiftui-how-to-center-text-in-a-form
// https://stackoverflow.com/questions/56923351/in-swiftui-how-do-i-set-the-environment-variable-of-editmode-in-an-xcodepreview

import SwiftUI
import Introspect

struct DetailView: View {
    @StateObject var site: Site
    @Environment(\.editMode) var editMode
    
    var body: some View {
        Group {
            //            if self.item == nil {
            //                NotSelectedView()
            //            }
            if self.editMode?.wrappedValue.isEditing == true {
                EditView(site: self.site, passwordProxy: PasswordProxy(site: self.site))
            }
            else {
                PresentView(site: self.site, passwordProxy: PasswordProxy(site: self.site))
            }
        }
        //        .navigationTitle(self.item.title ?? "")
        .toolbar {
            // https://stackoverflow.com/questions/64409091/swiftui-navigation-bar-button-disappears-after-entering-the-third-view-controll
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
} // DtailView

struct NotSelectedView: View {
    var body: some View {
        Text("No item is selected")
            .font(.largeTitle)
            .multilineTextAlignment(.center)
    }
} // NotSelectedView

struct NewItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var editMode: EditMode = .active
    
    var body: some View {
        DetailView(site: Site(context: self.viewContext))
            .environment(\.editMode, $editMode)
    }
}


struct EditView: View {
    @ObservedObject var site:          Site
    @ObservedObject var passwordProxy: PasswordProxy
    
    @ObservedObject var cryptor: CryptorUI = CryptorUI(name: "edit_password", duration: 30)
    
    @State private var title:           String = ""
    @State private var titleSort:       String = ""
    @State private var url:             String = ""
    @State private var userid:          String = ""
    @State private var mlength:         Float  = 4.0
    @State private var chars:           Int    = 0
    
    
    @Environment(\.editMode) var editMode
    @Environment(\.managedObjectContext) private var viewContext
    
    let lengthMin     =  4
    let lengthDefault =  8
    let lengthMax     = 32
    
    private let charsArray: [CypherCharacterSet] = [
        CypherCharacterSet.DecimalDigits,
        CypherCharacterSet.UppercaseLatinAlphabets,
        CypherCharacterSet.UpperCaseLettersSet,
        CypherCharacterSet.AlphaNumericsSet,
        CypherCharacterSet.Base64Set,
        CypherCharacterSet.ArithmeticCharactersSet,
        CypherCharacterSet.AlphaNumericSymbolsSet,
    ]  // .sorted { $0.rawValue < $1.rawValue }
    
    var section_site: some View {
        Section(header: Text("URL")) {
            TextField("URL",
                      text: self.$url,
                      onCommit: {
                        if self.title.isEmpty, let host = getDomain(from: self.url) {
                            self.title = host
                            if self.titleSort.isEmpty { self.titleSort = host }
                        }
                      })
                .introspectTextField { textField in
                    textField.becomeFirstResponder()
                }
                .modifier(ClearButton(text: self.$url))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
    
    var section_title: some View {
        Section(header: Text("Title")) {
            TextField("Title",
                      text: self.$title,
                      onCommit: {
                        if self.titleSort.isEmpty && !self.title.isEmpty {
                            self.titleSort = self.title
                        }
                      })
                .modifier(ClearButton(text: self.$title))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Sort Title", text: self.$titleSort)
                .modifier(ClearButton(text: self.$titleSort))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    var section_account: some View {
        Section(header: Text("Account")) {
            TextField("userid", text: self.$userid)
                .modifier(ClearButton(text: self.$userid))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
            
            HStack {
                if self.cryptor.opened {
                    TextField("", text: self.$passwordProxy.plainPassword) { _ in
                        do {
                            try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                        } catch let error {
                            J1Logger.shared.error("encrypt error = \(error)")
                        }
                    } onCommit: {
                        do {
                            try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                        } catch let error {
                            J1Logger.shared.error("encrypt error = \(error)")
                        }
                    }
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(String(repeating: "*", count: Int(self.site.length)))
                }
                Spacer()
                Button {
                    withAnimation {
                        self.cryptor.toggle {
                            switch $0 {
                            case nil:   // authentication failed, nothing to do
                                return
                            case false: // when closed, encrypt plainPass
                                do {
                                    try self.passwordProxy.endecrypt(cryptor: self.cryptor) // nothing to do
                                } catch let error {
                                    J1Logger.shared.error("encrypt error = \(error)")
                                }
                            case true:  // when opened, set a decrypted password to plainPass
                                do {
                                    try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                                } catch let error {
                                    J1Logger.shared.error("encrypt error = \(error)")
                                }
                            default:    // unknown status
                                break
                            }
                        } // toggle
                    }
                } label: {
                    Image(systemName: self.cryptor.opened ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                } // Button label
                .buttonStyle(PlainButtonStyle())
            } // HStack
            if self.cryptor.opened {
                Group {
                    HStack {
                        Text("\(Int(self.mlength))")   // String(format: "%3d", self.mlength))
                        Spacer()
                        Slider(value: self.$mlength,
                               in: Float(self.lengthMin)...Float(self.lengthMax))
                    }
                    Stepper(self.charsArray[self.chars].description,
                            value: self.$chars,
                            in: 0...self.charsArray.count - 1)
                    Button {
                        if let val = try? RandomData.shared.get(count: Int(self.mlength),
                                                                in: self.charsArray[self.chars]) {
                            self.passwordProxy.plain = val
                            do {
                                try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                            } catch let error {
                                J1Logger.shared.error("encrypt error = \(error)")
                            }
                        }
                    } label: {
                        Text("Generate Password")
                            .frame(minWidth : 0, maxWidth: .infinity,
                                   minHeight: 0, maxHeight: .infinity,
                                   alignment: .center)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                } // Group
                .transition(.move(edge: .top))
            } // if opened
        } // Section Account
    } // View section_account
    
    var section_memo: some View {
        Section(header: Text("Memo")) {
            Text(self.site.memo ?? "")
        }
    }
    
    var body: some View {
        Form {
            section_site
            section_title
            section_account
                .transition(.slide)
            section_memo
        }
        .navigationTitle(self.title)
        .onAppear {
            J1Logger.shared.debug("onAppear")
            self.site.on(state: .editing)
            
            self.title        = self.site.title ?? ""
            self.titleSort    = self.site.titleSort ?? ""
            self.url          = self.site.url   ?? ""
            self.userid       = self.site.userid ?? ""
            self.mlength = {
                let len = Int(self.site.maxLength)
                var val = 0
                switch len {
                case ..<self.lengthMin:
                    val = self.lengthDefault
                case self.lengthMin...self.lengthMax:
                    val = len
                case (self.lengthMax + 1)...:
                    val = self.lengthMax
                default:
                    val = self.lengthDefault
                }
                return Float(val)
            }()
            self.chars =
                self.charsArray.firstIndex {
                    CypherCharacterSet(rawValue: UInt32(self.site.charSet)).isSubset(of: $0) } ??
                self.charsArray.firstIndex {
                    $0 == CypherCharacterSet.AlphaNumericsSet } ??
                0
        }
        .onDisappear { () -> Void in
            J1Logger.shared.debug("onDisappear")
            let editing = self.editMode?.wrappedValue.isEditing
            J1Logger.shared.debug("editMode.isEditing = \(String(describing: editing))")
            
            self.site.off(state: .editing)
            
            update(&self.site.title    , with: self.title)
            update(&self.site.titleSort, with: self.titleSort)
            update(&self.site.url      , with: self.url)
            update(&self.site.userid   , with: self.userid)
            let i = Int16(self.mlength)
            if self.site.maxLength != i {
                self.site.maxLength = i
            }
            let c = self.charsArray[self.chars].rawValue
            if self.site.charSet != c {
                self.site.charSet = Int32(c)
            }
            
            if self.editMode?.wrappedValue.isEditing == true &&
                self.site.isEmptyState() &&
                self.title      == "" &&
                self.url        == "" &&
                self.userid     == "" &&
                self.passwordProxy.isEmpty {
                // new item is cancelled
                J1Logger.shared.debug("Site will delete \(self.site.description)")
                withAnimation {
                    self.viewContext.delete(self.site)
                }
            } else {
                self.passwordProxy.setTo(site: self.site) 
            }
            // NOTICE
            // Don't save Core Data context in this view,
            // otherwise the app crashes at "self.viewContext.save()"
            // as "Fatal error: Attempted to read an unowned reference but the object was already deallocated".
        }
        .sheet(isPresented: self.$cryptor.shouldShow) {
            self.cryptor.view
        }
    } // body
} // EditView

struct PresentView: View {
    @ObservedObject var site:          Site
    @ObservedObject var passwordProxy: PasswordProxy
    
    @EnvironmentObject var cryptor: CryptorUI
    
    var body: some View {
        Form {
            Section(header: Text("URL")) {
                if let url = URL(string: self.site.url ?? "") {
                    Link(url.absoluteString, destination: url)
                }
                else {
                    Text(self.site.url ?? "")
                }
            }
            Section(header: Text("Account")) {
                Text(self.site.userid ?? "")
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = self.site.userid ?? ""
                        }) {
                            Text("Copy")
                            Image(systemName: "doc.on.doc")
                        }
                    }
                HStack {
                    NavigationLink(destination: PasswordsView(site: self.site)) {
                        Group {
                            let str: String = {
                                guard self.cryptor.opened else {
                                    return String(repeating: "*", count: Int(self.site.length))
                                }
                                
                                do {
                                    try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                                } catch let error {
                                    J1Logger.shared.error("endecrypt error = \(error)")
                                }
                                return self.passwordProxy.plain
                            }()
                            Text(str)
                                .contextMenu {
                                    Button(action: {
                                        self.cryptor.open {
                                            if ($0 != nil) && $0! {
                                                do {
                                                    try self.passwordProxy.endecrypt(cryptor: self.cryptor)
                                                } catch let error {
                                                    J1Logger.shared.error("endecrypt error = \(error)")
                                                }
                                                UIPasteboard.general.string = self.passwordProxy.plain
                                            }
                                        }
                                    }) {
                                        Text("Copy")
                                        Image(systemName: "doc.on.doc")
                                    }
                                } // contextMenu
                        } // Group
                        Spacer()
                        Button {
                            self.cryptor.toggle()
                        } label: {
                            Image(systemName: self.cryptor.opened ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                    } // Navigation Link
                } // Hstack                
                Text(self.site.selectAt == nil ?
                        "" :
                        DateFormatter.localizedString(from: self.site.selectAt!,
                                                      dateStyle: .medium,
                                                      timeStyle: .medium))
            }
            Section(header: Text("Memo")) {
                Text(self.site.memo ?? "")
            }
        }
        //                .navigationBarItems(trailing: Image(systemName: self.ui.opened ? "lock.open" : "lock"))
        .navigationBarTitle(self.site.title ?? "", displayMode: .automatic)
        .sheet(isPresented: self.$cryptor.shouldShow) {
            self.cryptor.view
        }
        .onAppear {
            J1Logger.shared.debug("onAppear")
        }
        .onDisappear {
            J1Logger.shared.debug("onDisappear")
        }
    }
}

struct DetailView_Previews: PreviewProvider {
    @Environment(\.managedObjectContext) private var viewContext
    @State static var item: Site = Site()
    
    static var previews: some View {
        DetailView(site: item)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .onAppear {
                item.title = "title"
                item.url   = "http://www.apple.com/"
            }
    }
}
