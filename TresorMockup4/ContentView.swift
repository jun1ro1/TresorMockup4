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
//https://stackoverflow.com/questions/65126986/swiftui-bottombar-toolbar-disappears-when-going-back

import SwiftUI
import Introspect
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appState: AppState
    @StateObject       var category: Category
    @State private var predicate: NSPredicate? = nil
    @State private var searchText: String = ""
    @State private var sortDescriptors: [[NSSortDescriptor]] = [
        [ NSSortDescriptor(keyPath: \Site.titleSort, ascending: true),
          NSSortDescriptor(keyPath: \Site.url,       ascending: true)  ],
        [ NSSortDescriptor(keyPath: \Site.titleSort, ascending: false),
          NSSortDescriptor(keyPath: \Site.url,       ascending: false) ]
    ]
    @State private var sortDescriptorsIndex: Int = 0
    @State private var refresh = UUID() // Bug Workaround
    
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
                        sortDescriptors: self.sortDescriptors[self.sortDescriptorsIndex],
                        predicate: { () -> NSPredicate? in
                            let text  = self.searchText
                            if text == "" {
                                if CategoryKind(rawValue: self.category.kind) == .all {
                                    let kind = Int(CategoryKind.trash.rawValue)
                                    return NSPredicate(format: "category == nil OR category.kind !=\(kind)")
                                }
                                else {
                                    let kind: Int = Int(self.category.kind)
                                    return NSPredicate(format: "category != nil AND category.kind ==\(kind)")
                                }
                            }
                            else {
                                return NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
                            }
                        }(),
                        animation: .default),
                        delete: CategoryKind(rawValue: self.category.kind) == .trash)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NewItemView().onDisappear { self.refresh = UUID() }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    withAnimation() {
                        self.sortDescriptorsIndex += 1
                        self.sortDescriptorsIndex %= sortDescriptors.count
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }.id(self.refresh)
        .navigationTitle("Sites")
        .onAppear {
            self.appState.state = .normal
            let text = self.$searchText.wrappedValue
            self.predicate =
                (text == "") ?
                nil : NSPredicate(format: "title CONTAINS[cd] %@ OR url CONTAINS[cd] %@", text, text)
        }
    } // body
}

struct ItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var items:  FetchedResults<Site>
    @State        var delete: Bool
    
    var body: some View {
        ForEach(self.items, id: \.self) { item in
            NavigationLink(destination: DetailView(site: item)) {
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
        .onDelete {
            if self.delete {
                self.deleteItems(offsets: $0)
            } else {
                self.disposeItems(offsets: $0)
            }
        }
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
    
    private func disposeItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { self.items[$0] }.forEach { site in
                site.category = Category.CategoryTrash
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
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { self.items[$0] }.forEach { site in
                site.passwords?.allObjects.forEach { self.viewContext.delete($0 as! NSManagedObject) }
                self.viewContext.delete(site)
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
    }}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(category: Category())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
