//
//  BookDownloadSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI
import UniformTypeIdentifiers

struct BookDownloadSheet: View {
  let book: Book

  @Environment(\.dismiss) private var dismiss
  @State private var isDownloading = false
  @State private var cachedFileURL: URL?
  @State private var exportURL: URL?
  @State private var showFileExporter = false
  @State private var hasInitialized = false

  var body: some View {
    VStack(spacing: 16) {
      Text(book.downloadFileName)
        .font(.headline)

      if isDownloading {
        ProgressView()
          .progressViewStyle(.circular)
        Text("Downloading...")
          .font(.caption)
          .foregroundColor(.secondary)
      } else if cachedFileURL != nil {
        Text("Download complete")
          .font(.caption)
          .foregroundColor(.secondary)
        #if os(iOS) || os(macOS)
          Button {
            presentExporter()
          } label: {
            Label("Save to Files", systemImage: "square.and.arrow.up")
          }
          .adaptiveButtonStyle(.borderedProminent)
        #endif
      } else {
        Text("Ready to download this book file.")
          .font(.caption)
          .foregroundColor(.secondary)
        Button {
          startDownload()
        } label: {
          Label("Start Download", systemImage: "arrow.down.circle")
        }
        .adaptiveButtonStyle(.borderedProminent)
      }

      Button {
        dismiss()
      } label: {
        Label("Close", systemImage: "xmark")
      }
      .adaptiveButtonStyle(.plain)
    }
    .padding(PlatformHelper.sheetPadding)
    .presentationDragIndicator(.visible)
    .platformSheetPresentation(detents: [.medium])
    #if os(iOS) || os(macOS)
      .fileExporter(
        isPresented: $showFileExporter,
        document: exportURL.map { CachedFileDocument(url: $0) },
        contentType: .item,
        defaultFilename: book.downloadFileName
      ) { result in
        switch result {
        case .success:
          ErrorManager.shared.notify(message: "Book saved to Files")
          dismiss()
        case .failure(let error):
          ErrorManager.shared.alert(error: error)
        }
        exportURL = nil
      }
    #endif
    .task(id: book.id) {
      hasInitialized = false
      await initialize()
    }
  }

  private func initialize() async {
    guard !hasInitialized else { return }
    hasInitialized = true
    await refreshCachedFile()
    if cachedFileURL == nil {
      startDownload()
    }
  }

  private func startDownload() {
    guard !isDownloading else { return }
    isDownloading = true

    Task {
      do {
        let url = try await BookFileCache.shared.ensureOriginalFile(
          bookId: book.id,
          fileName: book.downloadFileName
        ) {
          let result = try await BookService.shared.downloadBookFile(bookId: book.id)
          return result.data
        }

        await MainActor.run {
          cachedFileURL = url
          isDownloading = false
        }
      } catch {
        await MainActor.run {
          isDownloading = false
        }
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func presentExporter() {
    guard let cachedFileURL = cachedFileURL else { return }
    exportURL = cachedFileURL
    showFileExporter = true
  }

  private func refreshCachedFile() async {
    let cached = await BookFileCache.shared.cachedOriginalFileURL(
      bookId: book.id,
      fileName: book.downloadFileName
    )
    await MainActor.run {
      cachedFileURL = cached
    }
  }
}
