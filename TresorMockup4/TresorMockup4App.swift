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
    @State private var authenticated: Bool = false
    @ObservedObject var handler = AuthenticationHandler {_ in}
    @State private var showView: Bool = false
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                NavigationLink("", destination: ContentView(),
                               isActive: self.$handler.authenticated)
                    .hidden()
            }
            .navigationBarHidden(true)
            .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
            .sheet(isPresented: self.$handler.shouldShow) {
                self.handler.view
            }
            .onAppear {
                self.handler.authenticate()
                #if DEBUG
                TestData.shared.saveDummyData()
                #endif
            }
        }
    }
}

