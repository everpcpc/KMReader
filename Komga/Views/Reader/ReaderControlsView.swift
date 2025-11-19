//
//  ReaderControlsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI
import UniformTypeIdentifiers

struct ReaderControlsView: View {
  @Binding var showingControls: Bool
  @Binding var showingReadingDirectionPicker: Bool
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let onDismiss: () -> Void

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @State private var showingPageJumpSheet = false

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  var body: some View {
    VStack {
      // Top bar
      VStack(spacing: 12) {
        HStack {
          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.title2)
              .foregroundColor(.white)
              .padding()
              .background(themeColorOption.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())

          Spacer()

          // Page count
          Button {
            guard !viewModel.pages.isEmpty else { return }
            showingPageJumpSheet = true
          } label: {
            Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pages.count)")
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(themeColorOption.color.opacity(0.8))
              .cornerRadius(20)
              .monospacedDigit()
          }
          .buttonStyle(.plain)
          .disabled(viewModel.pages.isEmpty)

          Spacer()

          // Display mode toggle button
          Button {
            showingReadingDirectionPicker = true
          } label: {
            Image(systemName: viewModel.readingDirection.icon)
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColorOption.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())
        }
      }
      .padding()
      .allowsHitTesting(true)

      // Series and book title
      if let book = currentBook {
        VStack(spacing: 4) {
          Text(book.seriesTitle)
            .font(.headline)
            .foregroundColor(.white)
          Text("#\(Int(book.number)) - \(book.metadata.title)")
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeColorOption.color.opacity(0.8))
        .cornerRadius(12)
      }

      Spacer()

      // Bottom slider
      VStack(spacing: 12) {
        HStack(spacing: 12) {
          // Save to file button
          Button {
            Task {
              await prepareSaveToFile()
            }
          } label: {
            Image(systemName: "folder.badge.plus")
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColorOption.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())

          Spacer()

          // Save to Photos button
          Button {
            Task {
              await saveCurrentPageToPhotos()
            }
          } label: {
            Image(systemName: "photo.badge.arrow.down.fill")
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColorOption.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())
        }

        ProgressView(
          value: Double(min(viewModel.currentPageIndex + 1, viewModel.pages.count)),
          total: Double(viewModel.pages.count)
        )
        .scaleEffect(x: viewModel.readingDirection == .rtl ? -1 : 1, y: 1)
      }
      .padding()
      .allowsHitTesting(true)
    }
    .allowsHitTesting(true)
    .transition(.opacity)
    .alert("Save Image", isPresented: $showSaveAlert) {
      Button("OK") {
        saveImageResult = nil
      }
    } message: {
      if let result = saveImageResult {
        switch result {
        case .success:
          Text("Image saved to Photos successfully")
        case .failure(let error):
          Text("Failed to save image: \(error)")
        }
      }
    }
    .onChange(of: saveImageResult) { oldValue, newValue in
      if newValue != nil {
        showSaveAlert = true
      }
    }
    .onChange(of: viewModel.readingDirection) { _, _ in
      if showingReadingDirectionPicker {
        showingReadingDirectionPicker = false
      }
    }
    .fileExporter(
      isPresented: $showDocumentPicker,
      document: fileToSave.map { ImageFileDocument(url: $0) },
      contentType: .item,
      defaultFilename: fileToSave?.lastPathComponent ?? "page"
    ) { result in
      // Clean up temporary file after export
      if let tempURL = fileToSave {
        try? FileManager.default.removeItem(at: tempURL)
      }
      fileToSave = nil
    }
    .sheet(isPresented: $showingPageJumpSheet) {
      PageJumpSheetView(
        totalPages: viewModel.pages.count,
        currentPage: viewModel.currentPageIndex + 1,
        onJump: jumpToPage
      )
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingReadingDirectionPicker) {
      ReadingDirectionPickerSheetView(viewModel: viewModel)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
  }

  private func jumpToPage(page: Int) {
    guard !viewModel.pages.isEmpty else { return }
    let clampedPage = min(max(page, 1), viewModel.pages.count)
    let targetIndex = clampedPage - 1
    if targetIndex != viewModel.currentPageIndex {
      viewModel.currentPageIndex = targetIndex
    }
  }

  // Prepare file for saving to Files app
  private func prepareSaveToFile() async {
    guard let page = viewModel.currentPage else {
      await MainActor.run {
        saveImageResult = .failure("Invalid page")
      }
      return
    }

    // Get page image info
    guard let cachedFileURL = viewModel.getCachedImageFileURL(page: page) else {
      await MainActor.run {
        saveImageResult = .failure("Image not available")
      }
      return
    }

    // Create a temporary file in a location accessible to document picker
    let tempDir = FileManager.default.temporaryDirectory
    let timestamp = ISO8601DateFormatter().string(from: Date())
      .replacingOccurrences(of: ":", with: "-")
      .replacingOccurrences(of: ".", with: "-")
    let originalName = page.fileName.isEmpty ? "page-\(page.number)" : page.fileName
    let fileName = "\(timestamp)_\(originalName)"
    let tempFileURL = tempDir.appendingPathComponent(fileName)

    // Copy file to temp location with proper extension
    do {
      if FileManager.default.fileExists(atPath: tempFileURL.path) {
        try FileManager.default.removeItem(at: tempFileURL)
      }
      try FileManager.default.copyItem(at: cachedFileURL, to: tempFileURL)

      await MainActor.run {
        fileToSave = tempFileURL
        showDocumentPicker = true
      }
    } catch {
      await MainActor.run {
        saveImageResult = .failure("Failed to prepare file: \(error.localizedDescription)")
      }
    }
  }

  // Save current page image to Photos
  private func saveCurrentPageToPhotos() async {
    guard let page = viewModel.currentPage else {
      await MainActor.run {
        saveImageResult = .failure("Invalid page")
      }
      return
    }
    let result = await viewModel.savePageImageToPhotos(page: page)

    await MainActor.run {
      switch result {
      case .success:
        saveImageResult = .success
      case .failure(let error):
        saveImageResult = .failure(error.localizedDescription)
      }
    }
  }
}

private struct ReadingDirectionPickerSheetView: View {
  @Bindable var viewModel: ReaderViewModel

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    NavigationStack {
      Form {
        Picker("Reading Direction", selection: $viewModel.readingDirection) {
          ForEach(ReadingDirection.allCases, id: \.self) { direction in
            HStack(spacing: 12) {
              Image(systemName: direction.icon)
                .foregroundStyle(themeColorOption.color)
              Text(direction.displayName)
            }
            .tag(direction)
          }
        }.pickerStyle(.inline)
      }
      .navigationTitle("Reading Mode")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

private struct PageJumpSheetView: View {
  let totalPages: Int
  let currentPage: Int
  let onJump: (Int) -> Void

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  @Environment(\.dismiss) private var dismiss
  @State private var pageValue: Int

  private var maxPage: Int {
    max(totalPages, 1)
  }

  private var canJump: Bool {
    totalPages > 0
  }

  private var rangeDescription: String {
    canJump ? "Range: 1 – \(totalPages)" : "No pages available"
  }

  private var sliderBinding: Binding<Double> {
    Binding(
      get: { Double(pageValue) },
      set: { newValue in
        pageValue = Int(newValue.rounded())
      }
    )
  }

  init(totalPages: Int, currentPage: Int, onJump: @escaping (Int) -> Void) {
    self.totalPages = totalPages
    self.currentPage = currentPage
    self.onJump = onJump

    let safeInitialPage = max(1, min(currentPage, max(totalPages, 1)))
    _pageValue = State(initialValue: safeInitialPage)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text(rangeDescription)
            .font(.headline)
            .foregroundStyle(.secondary)
          if canJump {
            Text("Current page: \(currentPage)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        if canJump {
          VStack(spacing: 20) {
            Text("Selected page: \(pageValue)")
              .font(.headline)

            VStack(spacing: 8) {
              Slider(
                value: sliderBinding,
                in: 1...Double(maxPage),
                step: 1
              )
              .tint(themeColorOption.color)

              HStack {
                Text("1")
                Spacer()
                Text("\(totalPages)")
              }
              .font(.footnote)
              .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Go to Page")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            dismiss()
          } label: {
            Label("Close", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            jumpToPage()
          } label: {
            Label("Jump", systemImage: "arrow.right.to.line")
          }
          .disabled(!canJump || pageValue == currentPage)
        }
      }
    }
  }

  private func jumpToPage() {
    guard canJump else { return }
    let clampedValue = min(max(pageValue, 1), totalPages)
    onJump(clampedValue)
    dismiss()
  }
}

// File document wrapper for fileExporter
struct ImageFileDocument: FileDocument {
  let url: URL
  let fileType: UTType?

  static var readableContentTypes: [UTType] {
    [.item]
  }

  static var writableContentTypes: [UTType] {
    [.item]
  }

  init(url: URL) {
    self.url = url
    // Detect file type from extension
    self.fileType = UTType(filenameExtension: url.pathExtension)
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents,
      let url = URL(dataRepresentation: data, relativeTo: nil)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.url = url
    self.fileType = UTType(filenameExtension: url.pathExtension)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let data = try Data(contentsOf: url)
    return FileWrapper(regularFileWithContents: data)
  }
}
