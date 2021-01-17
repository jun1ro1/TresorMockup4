//
//  DetailView.swift
//  TresorMockup4
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
    @StateObject var item: Site
    @Environment(\.editMode) var editMode
    
    var formatter = DateFormatter()
    
    var body: some View {
        Group {
//            if self.item == nil {
//                NotSelectedView()
//            }
            if self.editMode?.wrappedValue.isEditing == true {
                EditView(item: self.item)
            }
            else {
                PresentView(item: self.item)
            }
        }
//        .navigationTitle(self.item.title ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

struct NotSelectedView: View {
    var body: some View {
        Text("No item is selected")
            .font(.largeTitle)
            .multilineTextAlignment(.center)
    }
}

struct NewItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var editMode: EditMode = .active
    
    var body: some View {
        DetailView(item: Site(context: self.viewContext))
            .environment(\.editMode, $editMode)
    }
}


struct EditView: View {
    @ObservedObject var item:  Site
    
    @State private var title:       String = ""
    @State private var titleSort:   String = ""
    @State private var url:         String = ""
    @State private var userid:      String = ""
    @State private var password:    String = "PASSWORD"
    @State private var mlength:     Float  = 4.0
    @State private var chars:       Int    = 0
    
    @State private var showPassowrd: Bool = false
    
    @Environment(\.editMode) var editMode
    @Environment(\.managedObjectContext) private var viewContext
    
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
                        if self.title.isEmpty,
                           let host = getDomain(from: self.url) {
                            self.title = host
                            if self.titleSort.isEmpty {
                                self.titleSort = host
                            }
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
                PasswordTextField(title: "Password",
                                  text: self.$password,
                                  showPassword: self.$showPassowrd)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
                Button {
                    if !self.showPassowrd {
                        Cryptor.shared.open {
                            if $0 { self.showPassowrd.toggle() }
                        }
                    }
                    else {
                        self.showPassowrd.toggle()
                    }
                } label: {
                    Image(systemName: self.showPassowrd ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack {
                Text("\(Int(self.mlength))")   // String(format: "%3d", self.mlength))
                Spacer()
                Slider(value: self.$mlength, in: 4...32)
            }
            Stepper(self.charsArray[self.chars].description,
                    value: self.$chars,
                    in: 0...self.charsArray.count - 1)
            Button {
                if let val = try? RandomData.shared.get(count: Int(self.mlength),
                                                        in: self.charsArray[self.chars]) {
                    // self.detailItem?.passwordCurrent = val as NSString  // ***ENCRYPT***
                    self.password = val
                }
            } label: {
                Text("Generate Password")
                    .frame(minWidth : 0, maxWidth: .infinity,
                           minHeight: 0, maxHeight: .infinity,
                           alignment: .center)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    var section_memo: some View {
        Section(header: Text("Memo")) {
            Text(self.item.memo ?? "")
        }
    }
    
    var body: some View {
        Form {
            section_site
            section_title
            section_account
            section_memo
        }
        .navigationTitle(self.title)
        .onAppear {
            J1Logger.shared.debug("onAppear")
            var state = SiteState(rawValue: self.item.state)
            _ = state.insert(.editing)
            self.item.state = state.rawValue
            
            self.title     = self.item.title ?? ""
            self.titleSort = self.item.titleSort ?? ""
            self.url       = self.item.url   ?? ""
            self.userid    = self.item.userid ?? ""
            self.password  = self.item.password ?? ""
            self.mlength   = max(Float(self.item.maxLength), 4.0)
            self.chars     = (self.charsArray.firstIndex {
                                $0.rawValue >= self.item.charSet}) ?? 0
        }
        .onDisappear { () -> Void in
            let editing = self.editMode?.wrappedValue.isEditing
            J1Logger.shared.debug("editMode.isEditing = \(String(describing: editing))")
            
            var state = SiteState(rawValue: self.item.state)
            state.remove(.editing)
            self.item.state = state.rawValue
            
            update(&self.item.title    , with: self.title)
            update(&self.item.titleSort, with: self.titleSort)
            update(&self.item.url      , with: self.url)
            update(&self.item.userid   , with: self.userid)
            update(&self.item.password , with: self.password)
            let i = Int16(self.mlength)
            if self.item.maxLength != i {
                self.item.maxLength = i
            }
            if self.item.charSet != self.chars {
                self.item.charSet = Int32(self.chars)
            }
            
            if self.editMode?.wrappedValue.isEditing == true &&
                state.isEmpty &&
                self.title    == "" &&
                self.url      == "" &&
                self.userid   == "" &&
                self.password == "" {
                // new item is cancelled
                J1Logger.shared.debug("Site will delete \(self.item.description)")
                withAnimation {
                    self.viewContext.delete(self.item)
                }
            }
            else {
                var state = SiteState(rawValue: self.item.state)
                _ = state.insert(.saved)
                self.item.state = state.rawValue
            }
            
            // NOTICE
            // Don't save Core Data context in this view,
            // otherwise the app crashes at "self.viewContext.save()"
            // as "Fatal error: Attempted to read an unowned reference but the object was already deallocated".
            // Save the context in the content view.
//            guard self.viewContext.hasChanges else {
//                return
//            }
//            J1Logger.shared.debug("Site will save \(self.item.description)")
//            do {
//                try self.viewContext.save()
//            } catch {
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
        }
    }
}


struct PresentView: View {
    @ObservedObject var item: Site
    
    var body: some View {
        Form {
            Section(header: Text("URL")) {
                if let url = URL(string: self.item.url ?? "") {
                    Link(url.absoluteString, destination: url)
                }
                else {
                    Text(self.item.url ?? "")
                }
            }
            Section(header: Text("Account")) {
                Text(self.item.userid ?? "")
                Text(self.item.password ?? "")
                Text(self.item.selectAt == nil ?
                        "" :
                        DateFormatter.localizedString(from: self.item.selectAt!,
                                                      dateStyle: .medium,
                                                      timeStyle: .medium))
            }
            Section(header: Text("Memo")) {
                Text(self.item.memo ?? "")
            }
        }
        .navigationTitle(self.item.title ?? "")
    }
}

struct DetailView_Previews: PreviewProvider {
    @Environment(\.managedObjectContext) private var viewContext
    @State static var item: Site = Site()
    
    static var previews: some View {
        DetailView(item: item)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .onAppear {
                item.title = "title"
                item.url   = "http://www.apple.com/"
            }
    }
}
