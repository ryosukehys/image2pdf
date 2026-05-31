//
//  PDFPreviewView.swift
//  image2pdf
//
//  A thin SwiftUI wrapper around PDFKit's PDFView for live previews.
//

import PDFKit
import SwiftUI

struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        // Only rebuild the document when the underlying data actually changes.
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
    }
}
