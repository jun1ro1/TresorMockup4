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
    @ObservedObject var manager = AuthenticationManger.shared
    @State          var success: Bool = true
    
    var body: some Scene {
        WindowGroup {
            if self.success {
                NavigationView {
                    ContentView()
                }
                .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
                .onAppear {
                    AuthenticationManger.shared.authenticate { self.success = $0 }
                    #if DEBUG
                    TestData.shared.saveDummyData()
                    #endif
                }
                .sheet(isPresented: self.$manager.shouldShow) {
                    self.manager.view
                }
            }
            else {
                HaltView()
            }
        }
    }
}

