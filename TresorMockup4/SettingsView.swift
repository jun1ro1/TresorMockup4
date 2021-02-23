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
                Button("Export as a CSV file") {
                    self.fileURL = Site.export()
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
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(fileURL: nil)
    }
}
