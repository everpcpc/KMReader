//
//  PageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Photos
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS) || os(macOS)
  import VisionKit

  // View modifier that adds context menu with Live Text toggle (only when Live Text is not active)
  private struct PageContextMenu: ViewModifier {
    let page: BookPage?
    let pageIndex: Int
    let isSaving: Bool
    let isLiveTextActive: Bool
    let saveToPhotos: (BookPage) -> Void
    let imageFileURL: URL?
    let toggleLiveText: () -> Void

    func body(content: Content) -> some View {
      // Don't show context menu when Live Text is active to avoid blocking text selection
      if isLiveTextActive {
        content
      } else if let page = page {
        content.contextMenu {
          if ImageAnalyzer.isSupported {
            Button {
              toggleLiveText()
            } label: {
              Label("Show Live Text", systemImage: "text.viewfinder")
            }

            Divider()
          }

          Button {
            saveToPhotos(page)
          } label: {
            Label("Save to Photos", systemImage: "square.and.arrow.down")
          }
          .disabled(isSaving)

          if let imageFileURL = imageFileURL {
            ShareLink(item: imageFileURL, preview: SharePreview("Image", image: Image(systemName: "photo"))) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
          }
        }
      } else {
        content
      }
    }
  }
#endif

// Pure image display component without zoom/pan logic
struct PageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  var alignment: HorizontalAlignment = .center

  /// Cached image from memory for display
  @State private var displayImage: PlatformImage?
  @State private var loadError: String?
  @State private var isSaving = false
  #if os(iOS) || os(macOS)
    @State private var imageFileURL: URL?
  #endif
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true

  private var currentPage: BookPage? {
    guard pageIndex >= 0 && pageIndex < viewModel.pages.count else {
      return nil
    }
    return viewModel.pages[pageIndex]
  }

  private var pageNumberAlignment: Alignment {
    switch alignment {
    case .leading:
      return .topTrailing
    case .trailing:
      return .topLeading
    default:
      return .top
    }
  }

  #if os(iOS) || os(macOS)
    private var isLiveTextActive: Bool {
      viewModel.liveTextActivePageIndex == pageIndex
    }
  #endif

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
        Group {
          // Color.clear
          #if os(iOS) || os(macOS)
            if isLiveTextActive, ImageAnalyzer.isSupported {
              LiveTextImageView(image: displayImage)
                .overlay {
                  ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(Color.accentColor, lineWidth: 1)
                    Button {
                      viewModel.liveTextActivePageIndex = nil
                    } label: {
                      Label(String(localized: "Live Text"), systemImage: "xmark")
                    }
                    .optimizedControlSize()
                    .adaptiveButtonStyle(.borderedProminent)
                    .padding(4)
                  }
                }
            } else {
              Image(platformImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(alignment: pageNumberAlignment) {
                  if showPageNumber {
                    pageNumberOverlay
                  }
                }
            }
          #else
            Image(platformImage: displayImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .overlay(alignment: pageNumberAlignment) {
                if showPageNumber {
                  pageNumberOverlay
                }
              }
          #endif
        }
        #if os(iOS) || os(macOS)
          .modifier(
            PageContextMenu(
              page: currentPage,
              pageIndex: pageIndex,
              isSaving: isSaving,
              isLiveTextActive: isLiveTextActive,
              saveToPhotos: { page in
                Task { await saveImageToPhotos(page: page) }
              },
              imageFileURL: imageFileURL,
              toggleLiveText: {
                if viewModel.liveTextActivePageIndex == pageIndex {
                  viewModel.liveTextActivePageIndex = nil
                } else {
                  viewModel.liveTextActivePageIndex = pageIndex
                }
              }
            )
          )
        #else
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
            }
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
        #if os(iOS) || os(macOS)
          imageFileURL = url
        #endif
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
      return PlatformImage(data: data)
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

}
