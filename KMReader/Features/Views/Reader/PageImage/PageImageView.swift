//
//  PageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Photos
import SwiftUI
import UniformTypeIdentifiers

// Pure image display component without zoom/pan logic
struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  var pageNumberAlignment: Alignment = .top

  /// Cached image from memory for display
  @State private var displayImage: PlatformImage?
  @State private var loadError: String?
  @State private var isSaving = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true

  private var currentPage: BookPage? {
    guard pageIndex >= 0 && pageIndex < viewModel.pages.count else {
      return nil
    }
    return viewModel.pages[pageIndex]
  }

  private var pageNumberOverlay: some View {
    Text("\(pageIndex + 1)")
      .font(.system(size: 16, weight: .semibold, design: .rounded))
      .foregroundColor(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.black.opacity(0.6))
      )
      .padding(12)
      .allowsHitTesting(false)
  }

  var body: some View {
    Group {
      if let displayImage = displayImage {
        ZStack(alignment: pageNumberAlignment) {
          #if os(iOS) || os(tvOS)
            Image(uiImage: displayImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
          #elseif os(macOS)
            Image(nsImage: displayImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
          #endif

          if showPageNumber {
            pageNumberOverlay
          }
        }
        .contextMenu {
          if let page = currentPage {
            Button {
              Task {
                await saveImageToPhotos(page: page)
              }
            } label: {
              Label("Save to Photos", systemImage: "square.and.arrow.down")
            }
            .disabled(isSaving)

            #if os(iOS) || os(macOS)
              Button {
                Task {
                  await prepareSaveToFile(page: page)
                }
              } label: {
                Label("Save to Files", systemImage: "folder")
              }
              .disabled(isSaving)
            #endif
          }
        }
        #if os(iOS) || os(macOS)
          .fileExporter(
            isPresented: $showDocumentPicker,
            document: fileToSave.map { CachedFileDocument(url: $0) },
            contentType: .item,
            defaultFilename: fileToSave?.lastPathComponent ?? "page"
          ) { result in
            // Clean up temporary file after export
            if let tempURL = fileToSave {
              try? FileManager.default.removeItem(at: tempURL)
            }
            fileToSave = nil
          }
        #endif
      } else if let error = loadError {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 48))
            .foregroundColor(.white.opacity(0.7))
          Text("Failed to load image")
            .font(.headline)
            .foregroundColor(.white)
          Text(error)
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
          Button("Retry") {
            Task {
              await loadImage()
            }
          }
          .adaptiveButtonStyle(.borderedProminent)
          .padding(.top, 8)
        }
      } else {
        ProgressView()
          .padding()
      }
    }
    .animation(.default, value: loadError)
    .onAppear {
      // Synchronous check for preloaded image on appear for instant display
      guard displayImage == nil else { return }

      guard let page = currentPage else {
        loadError = "Invalid page index"
        return
      }

      // Try to get image from preloaded cache
      if let image = viewModel.preloadedImages[page.number] {
        displayImage = image
      }
    }
    .task(id: pageIndex) {
      // Async fallback for images not preloaded
      guard displayImage == nil else { return }
      await loadImage()
    }
  }

  private func loadImage() async {
    // Skip if already have image
    guard displayImage == nil else { return }

    loadError = nil

    guard let page = currentPage else {
      loadError = "Invalid page index"
      return
    }

    // Check preloaded images again (may have been loaded while waiting)
    if let image = viewModel.preloadedImages[page.number] {
      displayImage = image
      return
    }

    // Fall back to async loading if not preloaded
    if let url = await viewModel.getPageImageFileURL(page: page) {
      // Load and decode image
      if let image = await loadImageFromFile(fileURL: url) {
        displayImage = image
        // Store for future access
        viewModel.preloadedImages[page.number] = image
      } else {
        loadError = "Failed to decode image"
      }
    } else {
      loadError = "Failed to load page image. Please check your network connection"
    }
  }

  private func loadImageFromFile(fileURL: URL) async -> PlatformImage? {
    return await Task.detached(priority: .userInitiated) {
      guard let data = try? Data(contentsOf: fileURL) else {
        return nil
      }
      #if os(iOS) || os(tvOS)
        return UIImage(data: data)
      #elseif os(macOS)
        return NSImage(data: data)
      #endif
    }.value
  }

  private func saveImageToPhotos(page: BookPage) async {
    await MainActor.run {
      isSaving = true
    }

    let result = await viewModel.savePageImageToPhotos(page: page)
    await MainActor.run {
      isSaving = false
    }
    switch result {
    case .success:
      ErrorManager.shared.notify(message: String(localized: "notification.reader.imageSaved"))
    case .failure(let error):
      ErrorManager.shared.alert(error: error)
    }
  }

  private func prepareSaveToFile(page: BookPage) async {
    await MainActor.run {
      isSaving = true
    }

    // Get page image info
    guard let cachedFileURL = await viewModel.getCachedImageFileURL(page: page) else {
      await MainActor.run {
        isSaving = false
        ErrorManager.shared.alert(message: String(localized: "alert.reader.imageUnavailable"))
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
        isSaving = false
        fileToSave = tempFileURL
        showDocumentPicker = true
      }
    } catch {
      await MainActor.run {
        isSaving = false
        let message = String.localizedStringWithFormat(
          String(localized: "alert.reader.prepareFailed"),
          error.localizedDescription
        )
        ErrorManager.shared.alert(message: message)
      }
    }
  }
}
