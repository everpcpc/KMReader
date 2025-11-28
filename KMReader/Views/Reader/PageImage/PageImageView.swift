//
//  PageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Photos
import SDWebImage
import SDWebImageSwiftUI
import SwiftUI
import UniformTypeIdentifiers

// Pure image display component without zoom/pan logic
struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int

  @State private var imageURL: URL?
  @State private var loadError: String?
  @State private var isSaving = false
  @State private var showDocumentPicker = false
  @State private var fileToSave: URL?

  private var currentPage: BookPage? {
    guard pageIndex >= 0 && pageIndex < viewModel.pages.count else {
      return nil
    }
    return viewModel.pages[pageIndex]
  }

  var body: some View {
    Group {
      if let imageURL = imageURL {
        WebImage(
          url: imageURL,
          options: [.retryFailed, .scaleDownLargeImages],
          context: [
            // Limit single image memory to 50MB (will scale down if larger)
            .imageScaleDownLimitBytes: 50 * 1024 * 1024,
            .customManager: SDImageCacheProvider.pageImageManager,
            .storeCacheType: SDImageCacheType.memory.rawValue,
            .queryCacheType: SDImageCacheType.memory.rawValue,
          ]
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .transition(.fade)
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

            Button {
              Task {
                await prepareSaveToFile(page: page)
              }
            } label: {
              Label("Save to Files", systemImage: "folder")
            }
            .disabled(isSaving)
          }
        }
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
              loadError = nil
              if let page = currentPage {
                imageURL = await viewModel.getPageImageFileURL(page: page)
              } else {
                imageURL = nil
              }
              if imageURL == nil && loadError == nil {
                loadError = "Failed to load page image. Please check your network connection"
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 8)
        }
      } else {
        ProgressView()
          .padding()
      }
    }
    .task(id: pageIndex) {
      // Clear previous URL and error
      imageURL = nil
      loadError = nil

      // Download to cache if needed, then get file URL
      // SDWebImage will handle decoding and display
      if let page = currentPage {
        imageURL = await viewModel.getPageImageFileURL(page: page)
      } else {
        imageURL = nil
        loadError = "Invalid page index"
      }

      // If download failed, show error
      if imageURL == nil && loadError == nil {
        loadError = "Failed to load page image. Please check your network connection"
      }
    }
    .onDisappear {
      // Clear URL when view disappears
      imageURL = nil
    }
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
      ErrorManager.shared.notify(message: "Image saved to Photos successfully")
    case .failure(let error):
      ErrorManager.shared.alert(error: error)
    }
  }

  private func prepareSaveToFile(page: BookPage) async {
    await MainActor.run {
      isSaving = true
    }

    // Get page image info
    guard let cachedFileURL = viewModel.getCachedImageFileURL(page: page) else {
      await MainActor.run {
        isSaving = false
        ErrorManager.shared.alert(message: "Image not available")
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
        ErrorManager.shared.alert(message: "Failed to prepare file: \(error)")
      }
    }
  }
}
