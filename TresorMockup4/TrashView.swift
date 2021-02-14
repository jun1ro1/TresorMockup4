//
//  TrashView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/02/13.
//
/// https://www.appcoda.com/swiftui-search-bar/
/// https://stackoverflow.com/questions/63364529/swiftui-custom-list-with-foreach-delete-animation-not-working?rq=1

import SwiftUI
import Introspect
import CoreData

struct TrashView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.editMode)             var editMode
    @StateObject       var category:   Category
    @StateObject       var alert =  DeletionAlert()
    @State     private var searchText: String   = ""
    @State     private var selections: Set<Site> = []
    
    var body: some View {
        VStack {
            SearchBar(text: self.$searchText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .introspectTextField { textField in
                    textField.becomeFirstResponder()
                }.padding()
            TrashItemsView(
                items: FetchRequest<Site>(
                    entity: Site.entity(),
                    sortDescriptors: [ NSSortDescriptor(keyPath: \Site.titleSort, ascending: true),
                                       NSSortDescriptor(keyPath: \Site.url,       ascending: true)  ],
                    predicate: { () -> NSPredicate? in
                        let kind = Int(self.category.kind)
                        let text = self.searchText
                        if text == "" {
                            return NSPredicate(format: "category != nil AND category.kind ==\(kind)")
                        }
                        else {
                            return NSPredicate(
                                format: "(title CONTAINS[cd] %@ OR url CONTAINS[cd] %@) AND category != nil AND category.kind ==\(kind)", text, text)
                        }
                    }(),
                    animation: .default),
                selections: self.$selections)
        } // VStack
        .navigationTitle(self.category.name ?? "Trash")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        if self.editMode?.wrappedValue.isEditing == true {
                            self.editMode?.wrappedValue = .inactive
                            self.selections = []
                        } else {
                            self.editMode?.wrappedValue = .active
                        }
                    }
                } label: {
                    self.editMode?.wrappedValue.isEditing == true ?
                        Image(systemName: "checkmark.circle.fill") :
                        Image(systemName: "checkmark.circle")
                }
                
                EditButton()
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(
                    action: { self.alert.show() },
                    label:  { Image(systemName: "trash") }
                ).disabled(self.selections == [])
            }
        }
        .alert(isPresented: self.$alert.shouldShow) {
            self.alert.view!
        }
        .onAppear {
            J1Logger.shared.debug("onAppear appState.state = \(self.appState.state)")
            /// NOTICE
            /// Bound variables should not be changed unnecessarily,
            /// or it causes an unexpected view transition.
            if self.appState.state != .normal {
                self.appState.state = .normal
            }
            J1Logger.shared.debug("onAppear appState.state = \(self.appState.state)")
            self.alert.action = {
                self.deleteItems(items: self.selections)
                self.selections = []
            }
            
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
        .onDisappear {
            J1Logger.shared.debug("onDisappear appState.state = \(self.appState.state)")
        }
    } // body
    
    private func deleteItems(items: Set<Site>) {
        items.forEach { item in
            Site.delete(item, context: self.viewContext)
        }
        // NOTICE
        // Don't save Core Data context in this method,
        // otherwise the app crashes at "viewContext.save()"
        // Fatal error: Unresolved error Error Domain=NSCocoaErrorDomain Code=132001 "(null)"
        // UserInfo={message=attempt to recursively call -save: on the context aborted, stack trace=(
    }
}

struct TrashItemsView: View {
    @FetchRequest  var items:   FetchedResults<Site>
    @Binding       var selections: Set<Site>
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject   var alert =  DeletionAlert()
    
    var body: some View {
        List(selection: self.$selections) {
            ForEach(self.items, id: \.self) { item in
                NavigationLink(destination: TrashDetailView(site: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title ?? "")
                        Text(item.url ?? "")
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } // NavigationLink
                .contextMenu {
                    Button(action: {
                        item.category = nil
                    }) {
                        Text("Undo")
                        Image(systemName: "arrow.uturn.backward")
                    }
                }
            } // ForEach
        } // List
        .animation(.default, value: self.items.count)
    }
}

struct TrashDetailView: View {
    enum StateType {
        case none
        case deleted
        case undone
    }
    
    @ObservedObject var site: Site
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.presentationMode)     var presentationMode
    @State private var state: StateType = .none
    
    @StateObject       var alert =  DeletionAlert()
    
    var body: some View {
        Form {
            Section(header: Text("URL")) {
                if let url = URL(string: self.site.url ?? "") {
                    Link(url.absoluteString, destination: url)
                }
                else {
                    Text(self.site.url ?? "")
                }
            }
            Section(header: Text("Account")) {
                Text(self.site.userid ?? "")
                Text("********")
                Text(self.site.selectAt == nil ?
                        "" :
                        DateFormatter.localizedString(from: self.site.selectAt!,
                                                      dateStyle: .medium,
                                                      timeStyle: .medium))
            }
            Section(header: Text("Memo")) {
                Text(self.site.memo ?? "")
            }
        } // Form
        .navigationBarTitle(self.site.title ?? "", displayMode: .automatic)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(
                    action: { self.alert.show() },
                    label:  { Image(systemName: "trash") })
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(
                    action: {
                        self.state    = .undone
                        self.presentationMode.wrappedValue.dismiss()
                    },
                    label:  { Image(systemName: "arrow.uturn.backward") })
            }
        }
        .alert(isPresented: self.$alert.shouldShow) {
            self.alert.view!
        }
        .onAppear {
            J1Logger.shared.debug("onAppear")
            self.alert.action = {
                self.state = .deleted
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        .onDisappear {
            J1Logger.shared.debug("onDisappear")
            switch self.state {
            case .deleted:
                Site.delete(site, context: self.viewContext)
            case .undone:
                site.category = nil
            default:
                break
            }
        }
    }
}

class DeletionAlert: ObservableObject {
    @Environment(\.managedObjectContext) private var viewContext
    @Published var view:       Alert?    = nil
    @Published var shouldShow: Bool      = false
    @Published var action: (() -> Void)? = nil
    
    func show() {
        self.view = Alert(
            title:   Text("Are you sure to delete completely?"),
            message: Text("Unable to undo this action"),
            primaryButton: .default(
                Text("Cancel"),
                action: { self.shouldShow = false }
            ),
            secondaryButton: .destructive(
                Text("Delete"),
                action: {
                    self.shouldShow = false
                    self.action?()
                }
            )
        )
        self.shouldShow = true
    }
}
