//
//  SearchBar.swift
//
//
//  Copyright © Khanh N 2020.
//
// https://justcodewithkhanh.com/blogs/custom-search-bar-with-active-searching/

import SwiftUI

struct SearchBar : View {
    @Binding var text : String
    
    var body: some View {
        HStack{
            Image(systemName: "magnifyingglass").foregroundColor(.black)
            TextField("Search", text: $text)
            Spacer(minLength: 0)
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .foregroundColor(Color(UIColor.systemGray6))
                        .frame(width: 8, height: 8)
                        .background(Circle().foregroundColor(Color(UIColor.systemGray2)).frame(width: 16, height: 16))
                }
            }
        }.padding(5)
            .padding([.leading, .trailing], 6)
            .background(RoundedRectangle(cornerRadius: 30).foregroundColor(Color(UIColor.systemGray6)))
            .frame(maxWidth: .infinity)
    }
}
