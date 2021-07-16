//
//  ActivityIndicator.swift
//  TresorMockup4
//
//  
//  https://alpha3166.github.io/blog/20200222.html

import SwiftUI

struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool

    let style: UIActivityIndicatorView.Style

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        self.isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
