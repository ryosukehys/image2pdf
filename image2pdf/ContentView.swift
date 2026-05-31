//
//  ContentView.swift
//  image2pdf
//
//  Main screen: pick photos, arrange them, tune the page layout and export
//  a multi-page PDF.
//

import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject private var model = DocumentModel()

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPreview = false
    @State private var documentName = "Photos"

    var body: some View {
        NavigationStack {
            Group {
                if model.hasImages {
                    editor
                } else {
                    emptyState
                }
            }
            .navigationTitle("Image → PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task(id: pickerItems) {
                // Runs whenever the picker selection changes. The empty initial
                // value is a no-op (load returns early), so this only does work
                // after the user picks photos. Using `.task(id:)` avoids the
                // `onChange(of:)` closure form deprecated on iOS 17+/iPadOS 18.
                guard !pickerItems.isEmpty else { return }
                await model.load(items: pickerItems)
                pickerItems = []
            }
            .sheet(isPresented: $showingPreview) {
                PreviewSheet(model: model, documentName: documentName)
            }
            .overlay {
                if model.isImporting {
                    ProgressView("Importing…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableViewCompat(
            title: "No photos yet",
            systemImage: "photo.on.rectangle.angled",
            description: "Add one or more photos to turn them into a PDF."
        ) {
            PhotosPicker(selection: $pickerItems,
                         matching: .images) {
                Label("Add Photos", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Editor

    private var editor: some View {
        List {
            Section("Page setup") {
                Picker("Layout", selection: $model.layout) {
                    ForEach(PageLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }

                Picker("Paper size", selection: $model.pageSize) {
                    ForEach(PageSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }

                if model.pageSize != .fitImage {
                    Picker("Orientation", selection: $model.orientation) {
                        ForEach(PageOrientation.allCases) { orientation in
                            Text(orientation.displayName).tag(orientation)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Picker("画像の配置（余白の寄せ方）", selection: $model.alignment) {
                    ForEach(ImageAlignment.allCases) { alignment in
                        Text(alignment.displayName).tag(alignment)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Margin: \(Int(model.margin)) pt")
                    Slider(value: $model.margin, in: 0...96, step: 2)
                }

                if model.layout.imagesPerPage > 1 {
                    VStack(alignment: .leading) {
                        Text("Spacing: \(Int(model.spacing)) pt")
                        Slider(value: $model.spacing, in: 0...48, step: 2)
                    }
                }

                Toggle("Page numbers", isOn: $model.showPageNumbers)
                Toggle("Order numbers on photos", isOn: $model.showImageNumbers)
            }

            Section {
                ForEach(Array(model.images.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("Image \(index + 1)")
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                    }
                }
                .onMove(perform: model.move)
                .onDelete(perform: model.delete)
            } header: {
                Text("^[\(model.images.count) photo](inflect: true) · drag to reorder")
            }
        }
        .environment(\.editMode, .constant(.active))
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $pickerItems,
                         matching: .images) {
                Label("Add", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

            Button {
                showingPreview = true
            } label: {
                Label("Preview & Export", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.hasImages)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if model.hasImages {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    model.clear()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

/// Small shim so the empty state works on iOS 16 (where `ContentUnavailableView`
/// is unavailable) as well as iOS 17+.
private struct ContentUnavailableViewCompat<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            actions()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
