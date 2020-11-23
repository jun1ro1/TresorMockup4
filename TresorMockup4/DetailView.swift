//
//  DetailView.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/11/23.
//

import SwiftUI

struct DetailView: View {
    @ObservedObject var item: Site
    var formatter = DateFormatter()
    
    var body: some View {
        Form {
            Section(header: Text("Site")) {
                Text(self.item.title ?? "")
                Text(self.item.url ?? "")
                    .italic()
            }
            Section(header: Text("Account")) {
                Text(self.item.userid ?? "")
                Text(self.item.password ?? "")
                Text(self.item.selectAt == nil ?
                        "" :
                        DateFormatter.localizedString(from: self.item.selectAt!,
                                                      dateStyle: .medium,
                                                      timeStyle: .medium))
            }
            Section(header: Text("Memo")) {
                Text(self.item.memo ?? "")
            }
        }
        .navigationTitle(self.item.title ?? "")
    }
}

struct DetailView_Previews: PreviewProvider {
    @Environment(\.managedObjectContext) private var viewContext
    @State static var item: Site = Site()

    static var previews: some View {
        DetailView(item: item)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .onAppear {
                item.title = "title"
                item.url   = "http://www.apple.com/"
            }
    }
}
