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
    @ObservedObject var manager = AuthenticationManger.shared
    @State private var showView: Bool = false
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
            .onAppear {
                AuthenticationManger.shared.authenticate { success in
                    print(success ? "OK" : "NG")
                }
                #if DEBUG
                TestData.shared.saveDummyData()
                #endif
            }
            .sheet(isPresented: self.$manager.shouldShow) {
                self.manager.view
            }
        }
    }
}

