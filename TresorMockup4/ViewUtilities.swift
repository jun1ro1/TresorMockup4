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
        Group {
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
        .disableAutocorrection(true)
        .autocapitalization(.none)        
    }
}

// MARK: -
// https://sarunw.com/posts/how-to-save-export-image-in-mac-catalyst/
class DocumentPickerCoordinatorForExporting: NSObject, UIDocumentPickerDelegate {
    @Binding var fileURL: URL?
    
    init(fileURL: Binding<URL?>) {
        self._fileURL = fileURL
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        J1Logger.shared.info("url = \(url)")
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard self.fileURL != nil else { return }
        do {
            try FileManager.default.removeItem(at: self.fileURL!)
        } catch let error {
            J1Logger.shared.error("removeItem failed error = \(error)")
        }
    }
}

struct DocumentPickerForExporting: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    
    typealias UIViewControllerType = UIDocumentPickerViewController
    
    func makeCoordinator() -> DocumentPickerCoordinatorForExporting {
        return DocumentPickerCoordinatorForExporting(fileURL: self.$fileURL)
    }
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        guard self.fileURL != nil else {
            return UIDocumentPickerViewController()
        }
        let controller = UIDocumentPickerViewController(forExporting: [self.fileURL!])
        controller.delegate                 = context.coordinator
        controller.allowsMultipleSelection  = false
        controller.shouldShowFileExtensions = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

// MARK: -
// https://capps.tech/blog/read-files-with-documentpicker-in-swiftui
class DocumentPickerCoordinatorForOpening: NSObject, UIDocumentPickerDelegate {
    var block: (URL) -> Void
    
    init(block: @escaping (URL) -> Void) {
        self.block = block
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        J1Logger.shared.info("url = \(url)")
        self.block(url)
    }
}

struct DocumentPickerForOpening: UIViewControllerRepresentable {
    var block: (URL) -> Void
    
    typealias UIViewControllerType = UIDocumentPickerViewController
    
    func makeCoordinator() -> DocumentPickerCoordinatorForOpening {
        return DocumentPickerCoordinatorForOpening(block: self.block)
    }
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        controller.delegate                 = context.coordinator
        controller.allowsMultipleSelection  = false
        controller.shouldShowFileExtensions = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}
