//
//  ContentView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//
// https://www.appcoda.com/swiftui-search-bar/

// https://note.com/dngri/n/n26e807c880db
// https://www.raywenderlich.com/9335365-core-data-with-swiftui-tutorial-getting-started
// https://stackoverflow.com/questions/56533511/how-update-a-swiftui-list-without-animation
// https://stackoverflow.com/questions/63602263/swiftui-toolbaritem-doesnt-present-a-view-from-a-navigationlink
// https://stackoverflow.com/questions/57946197/navigationlink-on-swiftui-pushes-view-twice
// https://stackoverflow.com/questions/57871088/swiftui-view-and-fetchrequest-predicate-with-variable-that-can-change
// https://www.hackingwithswift.com/books/ios-swiftui/dynamically-filtering-fetchrequest-with-swiftui

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var updateCount: Int = 0
    @State private var added = false
    @State private var predicate: NSPredicate? = nil

    @State private var searchText: String = ""
//    var fetchRequest: FetchRequest<Site>
//    @FetchRequest var items: FetchedResults<Site>
    
//    init() {
//        J1Logger.shared.debug("init")
//        let sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)]
////        let text = "" // self.$searchText.wrappedValue
//        let predicate: NSPredicate? =
//            (text == "") ?
//            nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
//
//        self.predicate = NSPredicate(format: "")
//        self._items = FetchRequest<Site>(
//            entity: Site.entity(),
//            sortDescriptors: sortDescriptors,
////            predicate: $predicate.wrappedValue,
//            animation: .default)
//    }
//
    //    @FetchRequest(
    //        sortDescriptors: [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
    //        animation: .default) var items: FetchedResults<Site>
//        @FetchRequest(
//            sortDescriptors: [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
//            predicate:   ($searchText.wrappedValue == "") ?
//                nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text),
//            animation: .default) var items_fr: FetchedResults<Site>

    
//    var items: [Site] {
//        let sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)]
//        let text = self.$searchText.wrappedValue
//        let predicate: NSPredicate? =
//            (self.$searchText.wrappedValue == "") ?
//            nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
//
//        let request = NSFetchRequest<Site>(entityName: Site.entity().name!)
//        request.sortDescriptors = sortDescriptors
//        request.predicate       = predicate
//        let result = try? self.viewContext.fetch(request)
//        return result ?? []
//    }
    
    var body: some View {
        List {
            HStack {
                SearchBar(text: self.$searchText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(self.updateCount))
                    .frame(width: 0.0, height: 0.0, alignment: .trailing)
                    .hidden()
            }
            ItemsView(items: FetchRequest<Site>(
                entity: Site.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
                predicate:
                    (self.searchText == "") ?
                    nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@",
                                      self.searchText, self.searchText),
                animation: .default))

//            ForEach(self.items, id: \.self) { item in
//                NavigationLink(destination: DetailView(item: item)) {
//                    VStack(alignment: .leading) {
//                        Text(item.title ?? "")
//                        Text(item.url ?? "")
//                            .italic()
//                            .frame(maxWidth: .infinity, alignment: .trailing)
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                    }
//                }
//            }
//            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Sites")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NewItemView()) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
//            self.update()
            let text = self.$searchText.wrappedValue
            self.predicate =
                (text == "") ?
                nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
        }
     }
    
    
    private func update() {
        self.updateCount = (self.updateCount + 1) % 8
    }
    
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            //            let deleted = offsets.map { self.searchedItems[$0] }
//            offsets.map { self.items[$0] }.forEach {
//                viewContext.delete($0)
//            }
//
//            do {
//                try viewContext.save()
//                self.update()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
//        }
//    }
}

struct ItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var items: FetchedResults<Site>

    var body: some View {
//        List {
            ForEach(self.items, id: \.self) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title ?? "")
                        Text(item.url ?? "")
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete(perform: deleteItems)
//        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            //            let deleted = offsets.map { self.searchedItems[$0] }
            offsets.map { self.items[$0] }.forEach {
                viewContext.delete($0)
            }
            
            do {
                try viewContext.save()
//                self.update()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
