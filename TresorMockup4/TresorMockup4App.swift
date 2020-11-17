//
//  TresorMockup4App.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//

import SwiftUI

@main
struct TresorMockup4App: App {
    let persistenceController = PersistenceController.shared
    @State private var authentication: Bool = false
    @ObservedObject var handler = AuthenticationHandler {
        print($0 ? "OK" : "NG")
    }
    @State private var showView: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
                .onAppear {
                    self.handler.authenticate()
                }
                .sheet(isPresented: self.$handler.shouldShow) {
                    self.handler.view
                }
            Button("Authenticate") {
                self.handler.authenticate()
            }
        }
    }
}

