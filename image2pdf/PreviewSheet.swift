//
//  PreviewSheet.swift
//  image2pdf
//
//  Shows a live PDF preview and lets the user name and share the document.
//

import SwiftUI

struct PreviewSheet: View {
    @ObservedObject var model: DocumentModel
    @State var documentName: String

    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("File name", text: $documentName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .padding()

                Group {
                    if let pdfData {
                        PDFPreviewView(data: pdfData)
                    } else {
                        ProgressView("Rendering…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let url = exportURL() {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task(id: regenerationKey) {
                pdfData = model.makePDFData()
            }
        }
    }

    /// Recompute the preview whenever any setting that affects layout changes.
    private var regenerationKey: String {
        "\(model.images.count)-\(model.layout.rawValue)-\(model.pageSize.rawValue)-\(model.orientation.rawValue)-\(Int(model.margin))-\(Int(model.spacing))-\(model.showPageNumbers)-\(model.showImageNumbers)-\(model.alignment.rawValue)"
    }

    private func exportURL() -> URL? {
        model.exportPDF(named: documentName)
    }
}
