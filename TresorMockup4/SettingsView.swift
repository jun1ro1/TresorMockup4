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
        case export(fileURL: Binding<URL?>)
        case `import`(block: (URL) -> Void)
        case authenticate(cryptor: CryptorUI)
        
        // ignore parameters to compare Sheet values
        var id: ObjectIdentifier {
            switch self {
            case .backup(fileURL: _):
                return ObjectIdentifier(Self.self)
            case .restore(block: _):
                return ObjectIdentifier(Self.self)
            case .export(fileURL: _):
                return ObjectIdentifier(Self.self)
            case .import(block: _):
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
                return AnyView(DocumentPickerForOpening(block: block, fileType: [.zip]))
            case .export(let fileURL):
                return AnyView(DocumentPickerForExporting(fileURL: fileURL))
            case .import(let block):
                return AnyView(DocumentPickerForOpening(block: block, fileType: [.commaSeparatedText]))
            case .authenticate(let cryptor):
                return cryptor.view
            }
        }
    }
    
    enum Modal: Identifiable {
        case failure(error: Error)
        case deleteAll(block: () -> Void)
        
        var id: ObjectIdentifier {
            switch self {
            case .failure(_):
                return ObjectIdentifier(Self.self)
            case .deleteAll(block: _):
                return ObjectIdentifier(Self.self)
            }
        }
        
        var body: Alert {
            switch self {
            case .failure(let error):
                return Alert(title: Text("ERROR"),
                             message: Text(error.localizedDescription))

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
                    self.cryptor.open { opened in
                        guard opened == true else {
                            self.sheet = nil
                            return
                        }
                        self.fileURL = DataManager.shared.export(cryptor: self.cryptor)
                        guard self.fileURL != nil else { return }
                        self.sheet = .export(fileURL: self.$fileURL)
                        self.cryptor.close(keep: false)
                    }
                }
                Button("Import") {
                    self.sheet = .authenticate(cryptor: self.cryptor)
                    self.cryptor.open { opened in
                        guard opened == true else {
                            self.sheet = nil
                            self.cryptor.close(keep: false)
                            return
                        }
                        self.sheet = .import { url in
                            DataManager.shared.import(url: url, cryptor: self.cryptor)
                            J1Logger.shared.debug("fileURL = \(String(describing: url))")
                        }
                    }
                }
            } // Section
            Section(header: Text("Backup / Restore")) {
                Button("Backup") {
                    let _ = DataManager.shared.backup().sink { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                J1Logger.shared.error("error = \(error)")
                                self.modal = .failure(error: error)
                            }
                        } receiveValue: { fileURL in
                            self.fileURL = fileURL
                            guard self.fileURL != nil else { return }
                            self.sheet = .backup(fileURL: self.$fileURL)
                        }
                }
            Button("Restore") {
                self.sheet = .restore { url in
                    DataManager.shared.restore(url: url)
                }
                J1Logger.shared.debug("fileURL = \(String(describing: self.fileURL))")
            }
            } // Section
            Section(header: Text("Dangerous Operation").foregroundColor(.red)) {
                Button("Delete All Data") {
                    self.modal = .deleteAll { DataManager.shared.deleteAll() }
                }
            } // Section
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
