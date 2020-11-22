//
//  FilteredList.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/22.
//

import SwiftUI
import CoreData

// https://www.hackingwithswift.com/books/ios-swiftui/dynamically-filtering-fetchrequest-with-swiftui
struct FilteredList<T: NSManagedObject, Content: View>: View {
    var fetchRequest: FetchRequest<T>
//    var items: FetchedResults<T>
    var items: FetchedResults<T> { self.fetchRequest.wrappedValue }

    // this is our content closure; we'll call this once for each item in the list
    let content: (T) -> Content
    
    var body: some View {
        ForEach(self.items, id: \.self) { item in
            self.content(item)
        }
    }
    
    init(filterKey: String, searchText: String?, @ViewBuilder content: @escaping (T) -> Content) {
        let predicate: NSPredicate? =
            (searchText == nil || searchText!.isEmpty) ? nil : NSPredicate(format: "@K CONTAINS[cd] %@", filterKey, searchText!)
        self.fetchRequest = FetchRequest(
            sortDescriptors: [], // [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
            predicate: predicate,
            animation: .default)
        self.content = content
    }
}

