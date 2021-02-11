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
        List {
            ForEach(self.fetchedResults, id: \.self) {
                let category = $0 as Category
                NavigationLink(destination: ContentView(category: category),
                               tag: CategoryKind(rawValue: category.kind)!,
                               selection: self.$select) {
                    Text(category.name ?? "")
                }
            }
        }
        .navigationTitle("Categories")
        .onAppear {
            switch self.appState.state {
            case .startup:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.select = .all
                }
            default:
                self.select = CategoryKind.none
            }
        }
    }
}