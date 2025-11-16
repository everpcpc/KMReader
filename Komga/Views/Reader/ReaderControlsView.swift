//
//  ReaderControlsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReaderControlsView: View {
  @Binding var showingControls: Bool
  @Binding var showingReadingDirectionPicker: Bool
  let viewModel: ReaderViewModel
  let currentBook: Book?
  let themeColorOption: ThemeColorOption
  let onDismiss: () -> Void

  @State private var shareURL: URL?
  @State private var saveImageResult: SaveImageResult?
  @State private var showSaveAlert = false

  enum SaveImageResult: Equatable {
    case success
    case failure(String)
  }

  var body: some View {
    VStack {
      // Top bar
      VStack(spacing: 8) {
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
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())

          Spacer()

          // Page count in the middle
          Text("\(viewModel.currentPage + 1) / \(viewModel.pages.count)")
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(themeColorOption.color.opacity(0.8))
            .cornerRadius(20)

          Spacer()

          // Action buttons
          HStack(spacing: 12) {
            // Share button
            if let shareURL = shareURL {
              ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
                  .font(.title3)
                  .foregroundColor(.white)
                  .padding()
                  .background(themeColorOption.color.opacity(0.8))
                  .clipShape(Circle())
              }
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
            } else {
              Button {
                Task {
                  await prepareShare()
                }
              } label: {
                Image(systemName: "square.and.arrow.up")
                  .font(.title3)
                  .foregroundColor(.white)
                  .padding()
                  .background(themeColorOption.color.opacity(0.8))
                  .clipShape(Circle())
              }
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
            }

            // Save button
            Button {
              Task {
                await saveCurrentPage()
              }
            } label: {
              Image(systemName: "square.and.arrow.down")
                .font(.title3)
                .foregroundColor(.white)
                .padding()
                .background(themeColorOption.color.opacity(0.8))
                .clipShape(Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())

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
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
          }
        }
        .padding(.horizontal)
      }
      .padding(.top)
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
      VStack {
        ProgressView(
          value: Double(min(viewModel.currentPage + 1, viewModel.pages.count)),
          total: Double(viewModel.pages.count)
        )
        .scaleEffect(x: viewModel.readingDirection == .rtl ? -1 : 1, y: 1)
      }
      .padding()
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
  }

  // Prepare share URL for current page image
  private func prepareShare() async {
    guard viewModel.currentPage >= 0 && viewModel.currentPage < viewModel.pages.count else {
      return
    }

    // Get cached image file URL
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let diskCacheURL = cacheDir.appendingPathComponent("KomgaImageCache", isDirectory: true)
    let bookCacheDir = diskCacheURL.appendingPathComponent(viewModel.bookId, isDirectory: true)
    let fileURL = bookCacheDir.appendingPathComponent("page_\(viewModel.currentPage).data")

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return
    }

    await MainActor.run {
      shareURL = fileURL
      // Reset after a short delay to allow ShareLink to trigger
      Task {
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        await MainActor.run {
          shareURL = nil
        }
      }
    }
  }

  // Save current page image to Photos
  private func saveCurrentPage() async {
    let result = await viewModel.savePageImageToPhotos(pageIndex: viewModel.currentPage)

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
