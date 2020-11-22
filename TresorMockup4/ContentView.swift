//
//  ContentView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/14.
//
// https://www.appcoda.com/swiftui-search-bar/
// https://www.hackingwithswift.com/books/ios-swiftui/dynamically-filtering-fetchrequest-with-swiftui

// https://note.com/dngri/n/n26e807c880db
// https://www.raywenderlich.com/9335365-core-data-with-swiftui-tutorial-getting-started

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
        
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
        animation: .default) var items: FetchedResults<Site>
    
    var searchedItems: [Site] {
        let sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)]
        let predicate: NSPredicate? =
            (self.$searchText.wrappedValue == "") ?
            nil : NSPredicate(format: "title CONTAINS[cd] %@",  self.$searchText.wrappedValue)
        
        let request = NSFetchRequest<Site>(entityName: Site.entity().name!)
        request.sortDescriptors = sortDescriptors
        request.predicate       = predicate
        let result = try? self.viewContext.fetch(request)
        return result ?? []
    }

    var body: some View {
        NavigationView {
            List {
                SearchBar(text: self.$searchText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(self.searchedItems, id: \.self) { item in
                    VStack(alignment: .leading) {
                        Text(item.title ?? "")
                        Text(item.url ?? "")
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationBarTitle("Sites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addItem, label: {
                        Image(systemName: "plus")
                    })
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Site(context: viewContext)
            newItem.title     = "newly added"
            newItem.titleSort = newItem.title
            
            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
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
