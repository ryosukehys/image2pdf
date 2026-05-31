//
//  DocumentModel.swift
//  image2pdf
//
//  Observable state for the screen: selected images, page settings and
//  the resulting PDF.
//

import Combine
import PhotosUI
import SwiftUI

/// A selected photo with a stable identity so it can be reordered and deleted.
struct SelectedImage: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
}

@MainActor
final class DocumentModel: ObservableObject {

    @Published var images: [SelectedImage] = []

    @Published var pageSize: PageSize = .a4
    @Published var orientation: PageOrientation = .auto
    @Published var layout: PageLayout = .one
    @Published var margin: Double = 24
    @Published var spacing: Double = 12
    @Published var showPageNumbers: Bool = true
    @Published var showImageNumbers: Bool = true
    @Published var alignment: ImageAlignment = .center

    @Published var isImporting = false

    var hasImages: Bool { !images.isEmpty }

    var options: PDFGenerator.Options {
        PDFGenerator.Options(
            pageSize: pageSize,
            orientation: orientation,
            layout: layout,
            margin: CGFloat(margin),
            spacing: CGFloat(spacing),
            showPageNumbers: showPageNumbers,
            showImageNumbers: showImageNumbers,
            alignment: alignment
        )
    }

    // MARK: - Importing

    /// Loads `UIImage`s from the items returned by `PhotosPicker` and appends
    /// them, preserving the order the user picked them in.
    func load(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        var loaded: [SelectedImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(SelectedImage(image: image))
            }
        }
        images.append(contentsOf: loaded)
    }

    // MARK: - Editing

    func move(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
    }

    func delete(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
    }

    func clear() {
        images.removeAll()
    }

    // MARK: - PDF

    func makePDFData() -> Data? {
        PDFGenerator.makePDF(from: images.map(\.image), options: options)
    }

    /// Writes the PDF to a temporary file and returns its URL, suitable for
    /// `ShareLink`/`UIActivityViewController`. Returns nil if there is nothing
    /// to export.
    func exportPDF(named name: String = "Photos") -> URL? {
        guard let data = makePDFData() else { return nil }
        let safeName = name.isEmpty ? "Photos" : name
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
