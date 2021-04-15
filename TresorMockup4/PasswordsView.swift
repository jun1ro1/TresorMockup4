//
//  PasswordsView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/06.
//

import SwiftUI

struct PasswordsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var cryptor: CryptorUI

    @StateObject var site: Site

    var body: some View {
        List {
            PasswordItemsView(site: self.site,
                              items: FetchRequest<Password>(
                                entity: Password.entity(),
                                sortDescriptors: [NSSortDescriptor(keyPath: \Password.selectedAt, ascending: false)],
                                predicate: NSPredicate(format: "site == %@", self.site),
                                animation: .default),
                              cryptor: self.cryptor)
        }
        .navigationTitle("Passwords History")
        .navigationBarItems(trailing:
                                Button {
                                    self.cryptor.toggle()
                                } label: {
                                    Image(systemName: self.cryptor.opened ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
        )
        .sheet(isPresented: self.$cryptor.shouldShow) {
            self.cryptor.view
        }
    } // body
}

struct PasswordItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject    var site: Site
    @FetchRequest   var items: FetchedResults<Password>
    @ObservedObject var cryptor: CryptorUI
    
    var body: some View {
        ForEach(self.items, id: \.self) { item in
            let pass = item as Password
            let str: String = {
                guard self.cryptor.opened else {
                    return String(repeating: "*", count: Int(item.length))
                }
                guard let cipher = pass.password else {
                    return ""
                }
                guard let plain = try? cryptor.decrypt(cipher: cipher) else {
                    J1Logger.shared.error("decrypt failed: \(cipher)")
                    return ""
                }
                return plain
            }()
            VStack(alignment: .leading) {
                Text(str)
                    .contextMenu {
                        Button(action: {
                            self.cryptor.open {
                                if ($0 != nil) && $0! {
                                    guard let cipher = pass.password else {
                                        return
                                    }
                                    guard let plain = try? cryptor.decrypt(cipher: cipher) else {
                                        J1Logger.shared.error("decrypt failed: \(cipher)")
                                        return
                                    }
                                    UIPasteboard.general.string = plain
                                }
                            }
                        }) {
                            Text("Copy")
                            Image(systemName: "doc.on.doc")
                        }
                        Button(action: {
                            item.select()
                        }) {
                            Text("Select")
                            Image(systemName: "checkmark.circle")
                        }
                    } // contextMenu
                Text(pass.selectedAt == nil ?
                        "" :
                        DateFormatter.localizedString(from: pass.selectedAt!,
                                                      dateStyle: .medium,
                                                      timeStyle: .medium))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.caption)
                    .foregroundColor(.gray)
            } // VStack
        } // ForEach
    } // body
}
