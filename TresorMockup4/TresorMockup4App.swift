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
    @State private var showView: Bool = false

    var body: some Scene {
        WindowGroup {
            VStack {
            ContentView()
                .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
                .onAppear {
                    self.showView = AuthenticationManger.shared.authentication { success in
                        self.authentication = success
                        self.showView = false
                    }
                }
                .sheet(isPresented: self.$showView) {
                    AuthenticationManger.shared.authenticationView
                }
                self.authentication ? Text("OK") : Text("NG")
                Button("Authenticate") {
                    self.showView = AuthenticationManger.shared.authentication { success in
                        self.authentication = success
                        self.showView = false
                    }
                }
            }
        }
    }
}
