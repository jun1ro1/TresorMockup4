//
//  SettingsView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/21.
//

import Foundation
import SwiftUI

import Zip

struct SettingsView: View {
    @State var fileURL: URL?
    @State var sheet:   Sheet? = nil

    // https://qiita.com/1amageek/items/e90e1cfb0ad497e8b27a
    // https://stackoverflow.com/questions/57409804/how-to-confirm-an-enumeration-to-identifiable-protocol-in-swift
    // https://qiita.com/hachinobu/items/392c96820588d1c03b0c
    
    enum Sheet: View, Identifiable {
        case backup (fileURL: Binding<URL?>)
        case restore(block: (URL) -> Void)
        
        // ignore parameters to compare values
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
        } // Form
        .sheet(item: self.$sheet) {
            $0.body
        }
        .navigationTitle("Settings")
    } // View
    
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
        
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(fileURL: nil)
    }
}
