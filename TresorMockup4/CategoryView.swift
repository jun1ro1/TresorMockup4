//
//  CategoryView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/09.
//

import Foundation
import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: Category.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Category.kind, ascending: false)],
                  predicate: nil,
                  animation: .default) var fetchedResults: FetchedResults<Category>
    @State var select: CategoryKind? = CategoryKind.none
    
    var body: some View {
        VStack {
            List {
                ForEach(self.fetchedResults, id: \.self) {
                    let category = $0 as Category
                    NavigationLink(destination: ContentView(category: category)) {
                        Text(category.name ?? "")
                    }
                }
            }
            NavigationLink(destination: ContentView(category: Category.CategoryAll!)
                            .environmentObject(self.appState),  // Workaround
                           tag: CategoryKind(rawValue: CategoryKind.all.rawValue)!,
                           selection: self.$select) {
                EmptyView()
            }
            // Workaround for iPad
//            Fatal error: No ObservableObject of type AppState found. A View.environmentObject(_:) for AppState may be missing as an ancestor of this view.: file SwiftUI, line 0
//            2021-02-13 09:31:04.571705+0900 TresorMockup4[3897:299845] Fatal error: No ObservableObject of type AppState found. A View.environmentObject(_:) for AppState may be missing as an ancestor of this view.: file SwiftUI, line 0
            
        }
        .navigationTitle("Categories")
        .onAppear {
            switch self.appState.state {
            case .startup:
//              self.select = .all
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.select = .all
                }
            default:
                self.select = CategoryKind.none
            }
        }
    }
}
