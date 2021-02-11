//
//  CategoryView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/09.
//

import Foundation
import SwiftUI

struct CategoryView: View {
    @Environment(\.appState) var appState
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: Category.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Category.kind, ascending: false)],
                  predicate: nil,
                  animation: .default) var fetchedResults: FetchedResults<Category>
    @State var select: CategoryKind? = CategoryKind.none

    var body: some View {
        List {
            ForEach(self.fetchedResults, id: \.self) {
                let entity = $0 as Category
                NavigationLink(destination: ContentView(),
                               tag: CategoryKind(rawValue: entity.kind)!,
                               selection: self.$select) {
                    Text(entity.name ?? "")
                }
            }
        }
        .navigationTitle("Categories")
        .onAppear {
            switch self.appState.wrappedValue {
            case .startup:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.select = .all
                }
            default:
                self.select = CategoryKind.none
            }
        }
    }
}
