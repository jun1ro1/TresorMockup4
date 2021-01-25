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
    @ObservedObject var ui = CryptorUI.shared
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
                            self.ui.open()
                            #if DEBUG
                            TestData.shared.saveDummyData()
                            #endif
                        }
                        .sheet(isPresented: self.$ui.shouldShow) {
                            self.ui.view
                        }
                }
            }
        }
    }
}

// MARK: - OpeningView
struct OpeningView: View {
    private let title = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .multilineTextAlignment(.center)
            .padding()
    }
}

// MARK: - HaltView
struct HaltView: View {
    private let title = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()
            Text("Authentication Failed\nCan not continue.")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
