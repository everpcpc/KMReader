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
  var pageNumberAlignment: Alignment = .top

  @State private var imageURL: URL?
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
      if let imageURL = imageURL {
        ZStack(alignment: pageNumberAlignment) {
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
          .placeholder {
            ProgressView()
          }
          .resizable()
          .aspectRatio(contentMode: .fit)
          .transition(.opacity)

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
          .adaptiveButtonStyle(.borderedProminent)
          .padding(.top, 8)
        }
      } else {
        ProgressView()
          .padding()
      }
    }
    .animation(.easeInOut(duration: 0.25), value: imageURL)
    .task(id: pageIndex) {
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
