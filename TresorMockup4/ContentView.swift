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
import Introspect
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var added = false
    @State private var predicate: NSPredicate? = nil    
    @State private var searchText: String = ""
       
    var body: some View {
        List {
            HStack {
                SearchBar(text: self.$searchText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .introspectTextField { textField in
                        textField.becomeFirstResponder()
                    }
            }
            ItemsView(items: FetchRequest<Site>(
                        entity: Site.entity(),
                        sortDescriptors: [NSSortDescriptor(keyPath: \Site.titleSort, ascending: true)],
                        predicate: { () -> NSPredicate? in
                            let text = self.searchText
                            return (text == "") ? nil :
                                NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
                        }(),
                        animation: .default))
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
            let text = self.$searchText.wrappedValue
            self.predicate =
                (text == "") ?
                nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
        }
    }
}

struct ItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var items: FetchedResults<Site>
    
    var body: some View {
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
        .onAppear {
            if self.viewContext.hasChanges {
                do {
                    try self.viewContext.save()
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
                J1Logger.shared.debug("save context")
            }            
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { self.items[$0] }.forEach {
                viewContext.delete($0)
            }
            
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
