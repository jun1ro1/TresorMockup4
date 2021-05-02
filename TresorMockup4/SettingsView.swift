//
//  SettingsView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/21.
//

import Foundation
import CoreData
import SwiftUI

import Zip

struct SettingsView: View {
    @State var fileURL: URL?
    @State var sheet:   Sheet? = nil
    @State var modal:   Modal? = nil
    
    @ObservedObject var cryptor: CryptorUI = CryptorUI(name: "export_import")

    // https://qiita.com/1amageek/items/e90e1cfb0ad497e8b27a
    // https://stackoverflow.com/questions/57409804/how-to-confirm-an-enumeration-to-identifiable-protocol-in-swift
    // https://qiita.com/hachinobu/items/392c96820588d1c03b0c
    
    enum Sheet: View, Identifiable {
        case backup (fileURL: Binding<URL?>)
        case restore(block: (URL) -> Void)
        case authenticate(cryptor: CryptorUI)
        
        // ignore parameters to compare Sheet values
        var id: ObjectIdentifier {
            switch self {
            case .backup(fileURL: _):
                return ObjectIdentifier(Self.self)
            case .restore(block: _):
                return ObjectIdentifier(Self.self)
            case .authenticate(cryptor: _):
                return ObjectIdentifier(Self.self)
            }
        }

        var body: some View {
            switch self {
            case .backup(let fileURL):
                return AnyView(DocumentPickerForExporting(fileURL: fileURL))
            case .restore(let block):
                return AnyView(DocumentPickerForOpening(block: block))
            case .authenticate(let cryptor):
                return cryptor.view
            }
        }
    }
    
    enum Modal: Identifiable {
        case deleteAll(block: () -> Void)

        var id: ObjectIdentifier {
            switch self {
            case .deleteAll(block: _):
                return ObjectIdentifier(Self.self)
            }
        }
        
        var body: Alert {
            switch self {
            case .deleteAll(let block):
                return Alert(title: Text("Delete All Data"),
                             message: Text("Are you sure? Cannot undo."),
                             primaryButton:   .cancel(Text("Cancel")),
                             secondaryButton: .destructive(Text("Delete All Data"),
                                                           action: block))
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Export / Imoort")) {
                Button("Export") {
                    self.sheet = .authenticate(cryptor: self.cryptor)
                    defer { self.sheet = nil }
                    self.cryptor.open { opened in
                        guard opened == true else {
                            self.cryptor.close(keep: false)
                            return
                        }
                        self.fileURL = CoreDataUtility.shared.export(cryptor: self.cryptor)
                        guard self.fileURL != nil else { return }
                        self.sheet = .backup(fileURL: self.$fileURL)
                        self.cryptor.close(keep: false)
                    }
                }
                Button("Import") {
                    //
                }
            }
            Section(header: Text("Backup / Restore")) {
                Button("Backup") {
                    self.fileURL = CoreDataUtility.shared.backup()
                    guard self.fileURL != nil else { return }
                    self.sheet = .backup(fileURL: self.$fileURL)
                }
                Button("Restore") {
                    self.sheet = .restore { url in
                        CoreDataUtility.shared.restore(url: url)
                    }
                    J1Logger.shared.debug("fileURL = \(String(describing: self.fileURL))")
                }
            } // Section
            Section(header: Text("Dangerous Operation").foregroundColor(.red)) {
                Button("Delete All Data") {
                    self.modal = .deleteAll { CoreDataUtility.shared.deleteAll() }
                }
            }
        } // Form
        .sheet(item: self.$sheet) { $0.body }
        .alert(item: self.$modal) { $0.body }
        .navigationTitle("Settings")
    } // View
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(fileURL: nil)
    }
}
