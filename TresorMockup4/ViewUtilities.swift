//
//  Modifiers.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/12/26.
//
// https://stackoverflow.com/questions/58200555/swiftui-add-clearbutton-to-textfield
// https://developer.apple.com/forums/thread/121162

import SwiftUI

public struct ClearButton: ViewModifier {
    @Binding var text: String
    
    public func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
            // onTapGesture is better than a Button here when adding to a form
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .opacity(self.text == "" ? 0 : 1)
                .onTapGesture { self.text = "" }
        }
    }
}

struct PasswordTextField: View {
    @State   var title: String
    @Binding var text:  String
    @Binding var showPassword: Bool
    var onCommit: () -> Void = {}
    
    var body: some View {
        if self.showPassword {
            TextField(self.title,
                      text: self.$text,
                      onCommit: self.onCommit)
        }
        else {
            SecureField(self.title,
                        text: self.$text,
                        onCommit: self.onCommit)
        }
        
    }
}
