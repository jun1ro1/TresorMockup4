//
//  SettingsView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/21.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @State var fileURL: URL?
    @State var show:    Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Import / Export")) {
                Button("Backup") {
                    self.fileURL = self.backup()
                    guard self.fileURL != nil else { return }
                    self.show = true
                }
            } // Section
        } // Form
        .sheet(isPresented: self.$show) {
            DocumentPicker(fileURL: self.$fileURL)
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
        return urlSite!
   }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(fileURL: nil)
    }
}
