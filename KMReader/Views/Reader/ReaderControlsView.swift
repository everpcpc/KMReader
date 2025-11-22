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
  @Binding var readingDirection: ReadingDirection
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let onDismiss: () -> Void

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @State private var showingPageJumpSheet = false

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  private var displayedCurrentPage: String {
    guard viewModel.pages.count > 0 else { return "0" }
    if viewModel.currentPageIndex >= viewModel.pages.count {
      return "END"
    } else {
      return String(viewModel.currentPageIndex + 1)
    }
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
              .background(themeColor.color.opacity(0.8))
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
            HStack(spacing: 6) {
              Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
              Text("\(displayedCurrentPage) / \(viewModel.pages.count)")
                .monospacedDigit()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(themeColor.color.opacity(0.8))
            .cornerRadius(20)
            .overlay(
              RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .buttonStyle(.plain)
          .disabled(viewModel.pages.isEmpty)

          Spacer()

          // Display mode toggle button
          Button {
            showingReadingDirectionPicker = true
          } label: {
            Image(systemName: readingDirection.icon)
              .font(.title3)
              .foregroundColor(.white)
              .padding()
              .background(themeColor.color.opacity(0.8))
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
        .background(themeColor.color.opacity(0.8))
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
              .background(themeColor.color.opacity(0.8))
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
              .background(themeColor.color.opacity(0.8))
              .clipShape(Circle())
          }
          .frame(minWidth: 40, minHeight: 40)
          .contentShape(Rectangle())
        }

        ProgressView(
          value: Double(min(viewModel.currentPageIndex + 1, viewModel.pages.count)),
          total: Double(viewModel.pages.count)
        )
        .scaleEffect(x: readingDirection == .rtl ? -1 : 1, y: 1)
      }
      .padding()
      .allowsHitTesting(true)
    }
    .padding(.vertical)
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
    .onChange(of: readingDirection) { _, _ in
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
        currentPage: min(viewModel.currentPageIndex + 1, viewModel.pages.count),
        onJump: jumpToPage
      )
      .presentationDetents([.height(360)])
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingReadingDirectionPicker) {
      ReadingDirectionPickerSheetView(readingDirection: $readingDirection)
        .presentationDetents([.height(400)])
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
