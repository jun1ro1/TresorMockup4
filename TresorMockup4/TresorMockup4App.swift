//
//  TresorMockup4App.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//
// https://stackoverflow.com/questions/57730074/transition-animation-not-working-in-swiftui

import SwiftUI

@main
struct TresorMockup4App: App {
    let persistenceController   = PersistenceController.shared
    @ObservedObject var cryptor = CryptorUI()
    @State          var success: Bool? = nil
    
    var body: some Scene {
        WindowGroup {
            switch self.success {
            case true:
                NavigationView {
                    ContentView()
                }
                .environment(\.managedObjectContext, self.persistenceController.container.viewContext)
                .onAppear {
                    #if DEBUG
                    TestData.shared.saveDummyData(cryptor: self.cryptor)
                    #endif
                }
            case false:
                HaltView()
            default:
                OpeningView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            self.cryptor.open { self.success = $0 }
                        }
                    }
                    .sheet(isPresented: self.$cryptor.shouldShow) {
                        self.cryptor.view
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
            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.7)))
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
