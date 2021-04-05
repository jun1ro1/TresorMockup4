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

    // https://qiita.com/1amageek/items/e90e1cfb0ad497e8b27a
    // https://stackoverflow.com/questions/57409804/how-to-confirm-an-enumeration-to-identifiable-protocol-in-swift
    // https://qiita.com/hachinobu/items/392c96820588d1c03b0c
    
    enum Sheet: View, Identifiable {
        case backup (fileURL: Binding<URL?>)
        case restore(block: (URL) -> Void)
        
        // ignore parameters to compare Sheet values
        var id: ObjectIdentifier {
            switch self {
            case .backup(fileURL: _):
                return ObjectIdentifier(Self.self)
            case .restore(block: _):
                return ObjectIdentifier(Self.self)

            }
        }

        var body: some View {
            switch self {
            case .backup(let fileURL):
                return AnyView(DocumentPickerForExporting(fileURL: fileURL))
            case .restore(let block):
                return AnyView(DocumentPickerForOpening(block: block))
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
            Section(header: Text("Backup / Restore")) {
                Button("Backup") {
                    self.fileURL = self.backup()
                    guard self.fileURL != nil else { return }
                    self.sheet = .backup(fileURL: self.$fileURL)
                }
                Button("Restore") {
                    self.sheet = .restore { url in
                        self.restore(url: url)
                    }
                    J1Logger.shared.debug("fileURL = \(String(describing: self.fileURL))")
                }
            } // Section
            Section(header: Text("Dangerous Operation").foregroundColor(.red)) {
                Button("Delete All Data") {
                    self.modal = .deleteAll { self.deleteAll() }
                }
            }
        } // Form
        .sheet(item: self.$sheet) { $0.body }
        .alert(item: self.$modal) { $0.body }
        .navigationTitle("Settings")
    } // View
    
    func deleteAll() {
        Password.deleteAll()
        Site.deleteAll()
        Category.deleteAll()

        let viewContext = PersistenceController.shared.container.viewContext
        viewContext.refreshAllObjects()
    }
    
    func backup() -> URL {
        let now       = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.formatOptions = [.withFullDate, .withFullTime, .withSpaceBetweenDateAndTime]
        formatter.formatOptions.remove(
            [.withDashSeparatorInDate, .withColonSeparatorInTime,
             .withColonSeparatorInTimeZone, .withSpaceBetweenDateAndTime,
             .withTimeZone])
        let timestr = formatter.string(from: now)
        
        let urlCategory = Category.backup()
        let urlSite     = Site.backup()
        let urlPassword = Password.backup()
        J1Logger.shared.debug("urlCategory = \(String(describing: urlCategory))")
        J1Logger.shared.debug("urlSite     = \(String(describing: urlSite))")
        J1Logger.shared.debug("urlPassword = \(String(describing: urlPassword))")
        
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let urlZip = urlSite?.deletingLastPathComponent().appendingPathComponent("\(name)-\(timestr).zip")
        
        let urls =  [urlCategory!, urlSite!, urlPassword!]
        do {
            try Zip.zipFiles(paths: urls, zipFilePath: urlZip!, password: nil) { _ in
            }
        } catch let error {
            J1Logger.shared.error("Zip.zipFiles = \(error)")
        }
        
        urls.forEach { (url) in
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error {
                J1Logger.shared.error("removeItem \(url.absoluteString) error = \(error)")
            }
        }
        return urlZip!
    }
    
    func restore(url: URL) {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        J1Logger.shared.debug("url = \(String(describing: url))")
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        J1Logger.shared.debug("tempURL = \(tempURL)")

        do {
            try Zip.unzipFile(url, destination: tempURL, overwrite: true, password: nil)
        } catch let error {
            J1Logger.shared.error("Zip.unzipFile = \(error)")
        }

        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            var csvURL: URL
            csvURL = tempURL.appendingPathComponent("Site.csv", isDirectory: false)
            let loaderSite = Restorer<Site>(url: csvURL, searchingKeys: ["uuid", "url", "title"], context: context)
            loaderSite.load()
            
            csvURL = tempURL.appendingPathComponent("Category.csv", isDirectory: false)
            let loaderCategory = Restorer<Category>(url: csvURL, searchingKeys: ["uuid", "name"], context: context)
            loaderCategory.load()
            
            csvURL = tempURL.appendingPathComponent("Password.csv", isDirectory: false)
            let loaderPassword = Restorer<Password>(url: csvURL, searchingKeys: ["uuid", "password"], context: context)
            loaderPassword.load()
            
            loaderSite.link()
            loaderCategory.link()
            loaderPassword.link()
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    J1Logger.shared.error("Unresolved error \(nsError), \(nsError.userInfo)")
                }
                J1Logger.shared.debug("save context")
            }
            context.reset()
        }
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(fileURL: nil)
    }
}
