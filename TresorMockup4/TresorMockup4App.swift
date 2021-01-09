//
//  TresorMockup4App.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//

import SwiftUI

@main
struct TresorMockup4App: App {
    let persistenceController   = PersistenceController.shared
    @ObservedObject var manager = AuthenticationManger.shared
    @State          var success: Bool? = nil
    
    var body: some Scene {
        WindowGroup {
            switch self.success {
            case true:
                NavigationView {
                    ContentView()
                }
                .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
            case false:
                HaltView()
            default:
                NavigationView {
                    OpeningView()
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
            }
        }
    }
}

struct OpeningView: View {
    private let title = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .padding()
    }
}
