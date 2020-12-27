//
//  DetailView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/23.
//
// https://developer.apple.com/forums/thread/128366
// https://capibara1969.com/2625/
// https://stackoverflow.com/questions/57947581/why-buttons-dont-work-when-embedded-in-a-swiftui-form
// https://stackoverflow.com/questions/57518874/swiftui-how-to-center-text-in-a-form

import SwiftUI

struct DetailView: View {
    @ObservedObject var item: Site
    @Environment(\.editMode) var editMode
    
    var formatter = DateFormatter()
    
    var body: some View {
        Group {
            if self.editMode?.wrappedValue.isEditing == true {
                EditView(item: self.item)
            }
            else {
                PresentView(item: self.item)
            }
        }
        .navigationTitle(self.item.title ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

struct EditView: View {
    @ObservedObject var item:  Site
    
    @State private var title:    String = ""
    @State private var url:      String = ""
    @State private var userid:   String = ""
    @State private var password: String = "PASSWORD"
    @State private var mlength:  Float  = 4.0
    @State private var chars:    Int    = 0
    
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

    var body: some View {
        Form {
            Section(header: Text("Site")) {
                TextField("Title", text: self.$title)
                    .modifier(ClearButton(text: self.$title))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("URL", text: self.$url)
                    .modifier(ClearButton(text: self.$url))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .disableAutocorrection(true)
            }
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
                            AuthenticationManger.shared.authenticate {
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
            Section(header: Text("Memo")) {
                Text(self.item.memo ?? "")
            }
        }
        .onAppear {
            self.title    = self.item.title ?? ""
            self.url      = self.item.url   ?? ""
            self.userid   = self.item.userid ?? ""
            self.password = self.item.password ?? ""
            self.mlength  = max(Float(self.item.maxLength), 4.0)
            self.chars    = (self.charsArray.firstIndex {$0.rawValue >= self.item.charSet}) ?? 0
        }
        .onDisappear() {
            let editing = self.editMode?.wrappedValue.isEditing
            J1Logger.shared.debug("editMode.isEditing = \(String(describing: editing))")
            
            guard self.editMode?.wrappedValue.isEditing == false else {
                return
            }

            update(&self.item.title   , with: self.title)
            update(&self.item.url     , with: self.url)
            update(&self.item.userid  , with: self.userid)
            update(&self.item.password, with: self.password)
            let i = Int16(self.mlength)
            if self.item.maxLength != i {
                self.item.maxLength = i
            }
//            update(&self.item.maxLength, with: Int16(self.mlength))

            guard self.viewContext.hasChanges else {
                return
            }
            
            do {
                try self.viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}


struct PresentView: View {
    @ObservedObject var item: Site
    
    var body: some View {
        Form {
            Section(header: Text("Site")) {
                Text(self.item.title ?? "")
                Text(self.item.url ?? "")
                    .italic()
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
