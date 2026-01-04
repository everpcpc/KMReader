//
//  SettingsCacheView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsCacheView: View {
  @AppStorage("maxPageCacheSize") private var maxPageCacheSize: Int = 8
  @AppStorage("maxThumbnailCacheSize") private var maxThumbnailCacheSize: Int = 1
  @State private var showClearImageCacheConfirmation = false
  @State private var showClearAllImageCacheConfirmation = false
  @State private var showClearBookFileCacheConfirmation = false
  @State private var showClearAllBookFileCacheConfirmation = false
  @State private var showClearThumbnailCacheConfirmation = false
  @State private var showClearAllThumbnailCacheConfirmation = false
  @State private var imageCacheSize: Int64 = 0
  @State private var imageCacheCount: Int = 0
  @State private var bookFileCacheSize: Int64 = 0
  @State private var bookFileCacheCount: Int = 0
  @State private var thumbnailCacheSize: Int64 = 0
  @State private var thumbnailCacheCount: Int = 0
  @State private var isLoadingCacheSize = false

  #if os(iOS) || os(macOS)
    @State private var isEditingPageCacheSlider = false
    @State private var isEditingThumbnailCacheSlider = false

    private var maxCacheSizeBinding: Binding<Double> {
      Binding(
        get: { Double(maxPageCacheSize) },
        set: { maxPageCacheSize = Int($0) }
      )
    }

    private var maxThumbnailCacheSizeBinding: Binding<Double> {
      Binding(
        get: { Double(maxThumbnailCacheSize) },
        set: { maxThumbnailCacheSize = Int($0) }
      )
    }
  #else
    @State private var cacheSizeText: String = ""
    @State private var thumbnailCacheSizeText: String = ""

    private var cacheSizeTextFieldBinding: Binding<String> {
      Binding(
        get: { cacheSizeText.isEmpty ? "\(maxPageCacheSize)" : cacheSizeText },
        set: { newValue in
          cacheSizeText = newValue
          if let value = Int(newValue), value >= 1, value <= 20 {
            maxPageCacheSize = value
          }
        }
      )
    }

    private var thumbnailCacheSizeTextFieldBinding: Binding<String> {
      Binding(
        get: {
          thumbnailCacheSizeText.isEmpty ? "\(maxThumbnailCacheSize)" : thumbnailCacheSizeText
        },
        set: { newValue in
          thumbnailCacheSizeText = newValue
          if let value = Int(newValue), value >= 1, value <= 8 {
            maxThumbnailCacheSize = value
          }
        }
      )
    }
  #endif

  var body: some View {
    Form {
      Section(header: Text("Page")) {
        VStack(alignment: .leading, spacing: 8) {
          #if os(iOS) || os(macOS)
            HStack {
              Text("Maximum Size")
              Spacer()
              Text("\(maxPageCacheSize) GB")
                .foregroundColor(.secondary)
            }
            Slider(
              value: maxCacheSizeBinding,
              in: 1...20,
              step: 1
            ) { editing in
              isEditingPageCacheSlider = editing
            }
          #else
            HStack {
              Text("Maximum Size (GB)")
              Spacer()
              TextField("GB", text: cacheSizeTextFieldBinding)
                .frame(maxWidth: 240)
                .multilineTextAlignment(.trailing)
                .onAppear {
                  cacheSizeText = "\(maxPageCacheSize)"
                }
                .onChange(of: maxPageCacheSize) { _, newValue in
                  if cacheSizeText != "\(newValue)" {
                    cacheSizeText = "\(newValue)"
                  }
                }
            }
          #endif
          Text(
            "Adjust the maximum size of the page cache. Cache will be cleaned automatically when exceeded."
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }

        HStack {
          Text("Cached Size")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheSize(imageCacheSize))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Text("Cached Images")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheCount(imageCacheCount))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Button(role: .destructive) {
            showClearAllImageCacheConfirmation = true
          } label: {
            Text("Clear All")
              .frame(maxWidth: .infinity)
          }
          Button(role: .destructive) {
            showClearImageCacheConfirmation = true
          } label: {
            Text("Clear Current")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.bordered)
      }

      Section(header: Text(String(localized: "Cover"))) {
        VStack(alignment: .leading, spacing: 8) {
          #if os(iOS) || os(macOS)
            HStack {
              Text("Maximum Size")
              Spacer()
              Text("\(maxThumbnailCacheSize) GB")
                .foregroundColor(.secondary)
            }
            Slider(
              value: maxThumbnailCacheSizeBinding,
              in: 1...8,
              step: 1
            ) { editing in
              isEditingThumbnailCacheSlider = editing
            }
          #else
            HStack {
              Text("Maximum Size (GB)")
              Spacer()
              TextField("GB", text: thumbnailCacheSizeTextFieldBinding)
                .frame(maxWidth: 240)
                .multilineTextAlignment(.trailing)
                .onAppear {
                  thumbnailCacheSizeText = "\(maxThumbnailCacheSize)"
                }
                .onChange(of: maxThumbnailCacheSize) { _, newValue in
                  if thumbnailCacheSizeText != "\(newValue)" {
                    thumbnailCacheSizeText = "\(newValue)"
                  }
                }
            }
          #endif
          Text(
            "Adjust the maximum size of the cover cache. Cache will be cleaned automatically when exceeded."
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }

        HStack {
          Text("Cached Size")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheSize(thumbnailCacheSize))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Text(String(localized: "Cached Covers"))
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheCount(thumbnailCacheCount))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Button(role: .destructive) {
            showClearAllThumbnailCacheConfirmation = true
          } label: {
            Text("Clear All")
              .frame(maxWidth: .infinity)
          }
          Button(role: .destructive) {
            showClearThumbnailCacheConfirmation = true
          } label: {
            Text("Clear Current")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.bordered)
      }

      Section(header: Text("Book File")) {
        HStack {
          Text("Cached Size")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheSize(bookFileCacheSize))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Text("Cached Files")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheCount(bookFileCacheCount))
              .foregroundColor(.secondary)
          }
        }
        .tvFocusableHighlight()

        HStack {
          Button(role: .destructive) {
            showClearAllBookFileCacheConfirmation = true
          } label: {
            Text("Clear All")
              .frame(maxWidth: .infinity)
          }
          Button(role: .destructive) {
            showClearBookFileCacheConfirmation = true
          } label: {
            Text("Clear Current")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.bordered)
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.cache.title)
    .alert("Clear Page (Current Server)", isPresented: $showClearImageCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await ImageCache.clearCurrentInstanceDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.pageClearedCurrent")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove cached page images for the current server. Images will be re-downloaded when needed."
      )
    }
    .alert("Clear Page (All Servers)", isPresented: $showClearAllImageCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await ImageCache.clearAllDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.pageClearedAll")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached page images for all servers. Images will be re-downloaded when needed."
      )
    }
    .alert("Clear Book File (Current Server)", isPresented: $showClearBookFileCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await BookFileCache.clearCurrentInstanceDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.bookFileClearedCurrent")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove cached EPUB files for the current server. Files will be re-downloaded when needed."
      )
    }
    .alert("Clear Book File (All Servers)", isPresented: $showClearAllBookFileCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await BookFileCache.clearAllDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.bookFileClearedAll")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached EPUB files for all servers. Files will be re-downloaded when needed."
      )
    }
    .alert(String(localized: "Clear Cover (Current Server)"), isPresented: $showClearThumbnailCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await ThumbnailCache.clearCurrentInstanceDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.coverClearedCurrent")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove cached covers for the current server. Covers will be re-downloaded when needed."
      )
    }
    .alert(String(localized: "Clear Cover (All Servers)"), isPresented: $showClearAllThumbnailCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await ThumbnailCache.clearAllDiskCache()
          await MainActor.run {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cache.coverClearedAll")
            )
          }
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached covers for all servers. Covers will be re-downloaded when needed."
      )
    }
    .task {
      await loadCacheSize()
    }
    .onChange(of: maxPageCacheSize) {
      // Only trigger cache cleanup after slider dragging ends
      #if os(iOS) || os(macOS)
        guard !isEditingPageCacheSlider else { return }
      #endif
      Task {
        await ImageCache.cleanupDiskCacheIfNeeded()
        await loadCacheSize()
      }
    }
    .onChange(of: maxThumbnailCacheSize) {
      // Only trigger cache cleanup after slider dragging ends
      #if os(iOS) || os(macOS)
        guard !isEditingThumbnailCacheSlider else { return }
      #endif
      Task {
        await ThumbnailCache.cleanupDiskCacheIfNeeded()
        await loadCacheSize()
      }
    }
  }

  private func loadCacheSize() async {
    isLoadingCacheSize = true
    async let imageSize = ImageCache.getDiskCacheSize()
    async let imageCount = ImageCache.getDiskCacheCount()
    async let bookFileSize = BookFileCache.getDiskCacheSize()
    async let bookFileCount = BookFileCache.getDiskCacheCount()
    async let thumbnailSize = ThumbnailCache.getDiskCacheSize()
    async let thumbnailCount = ThumbnailCache.getDiskCacheCount()

    imageCacheSize = await imageSize
    imageCacheCount = await imageCount
    bookFileCacheSize = await bookFileSize
    bookFileCacheCount = await bookFileCount
    thumbnailCacheSize = await thumbnailSize
    thumbnailCacheCount = await thumbnailCount
    isLoadingCacheSize = false
  }

  private func formatCacheSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private func formatCacheCount(_ count: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
  }

}
