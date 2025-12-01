//
//  SettingsCacheView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsCacheView: View {
  @AppStorage("maxDiskCacheSizeMB") private var maxDiskCacheSizeMB: Int = 2048
  @State private var showClearImageCacheConfirmation = false
  @State private var showClearBookFileCacheConfirmation = false
  @State private var showClearThumbnailCacheConfirmation = false
  @State private var imageCacheSize: Int64 = 0
  @State private var imageCacheCount: Int = 0
  @State private var bookFileCacheSize: Int64 = 0
  @State private var bookFileCacheCount: Int = 0
  @State private var isLoadingCacheSize = false
  #if os(iOS) || os(macOS)
    private var maxCacheSizeBinding: Binding<Double> {
      Binding(
        get: { Double(maxDiskCacheSizeMB) },
        set: { maxDiskCacheSizeMB = Int($0) }
      )
    }
  #else
    @State private var cacheSizeText: String = ""

    private var cacheSizeTextFieldBinding: Binding<String> {
      Binding(
        get: { cacheSizeText.isEmpty ? "\(maxDiskCacheSizeMB)" : cacheSizeText },
        set: { newValue in
          cacheSizeText = newValue
          if let value = Int(newValue), value >= 512, value <= 8192 {
            maxDiskCacheSizeMB = value
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
              Text("\(maxDiskCacheSizeMB) MB")
                .foregroundColor(.secondary)
            }
            Slider(
              value: maxCacheSizeBinding,
              in: 512...8192,
              step: 256
            )
          #else
            HStack {
              Text("Maximum Size (MB)")
              Spacer()
              TextField("MB", text: cacheSizeTextFieldBinding)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
                .onAppear {
                  cacheSizeText = "\(maxDiskCacheSizeMB)"
                }
                .onChange(of: maxDiskCacheSizeMB) { _, newValue in
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
        #if os(tvOS)
          .focusable()
        #endif

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
        #if os(tvOS)
          .focusable()
        #endif

        Button(role: .destructive) {
          showClearImageCacheConfirmation = true
        } label: {
          HStack {
            Spacer()
            Text("Clear")
            Spacer()
          }
        }
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
        #if os(tvOS)
          .focusable()
        #endif

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
        #if os(tvOS)
          .focusable()
        #endif

        Button(role: .destructive) {
          showClearBookFileCacheConfirmation = true
        } label: {
          HStack {
            Spacer()
            Text("Clear")
            Spacer()
          }
        }
      }

      Section(header: Text("Thumbnail")) {
        Button(role: .destructive) {
          showClearThumbnailCacheConfirmation = true
        } label: {
          HStack {
            Spacer()
            Text("Clear")
            Spacer()
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle("Cache")
    .alert("Clear Page", isPresented: $showClearImageCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await ImageCache.clearAllDiskCache()
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached page images from disk. Images will be re-downloaded when needed."
      )
    }
    .alert("Clear Book File", isPresented: $showClearBookFileCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await BookFileCache.clearAllDiskCache()
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached EPUB files from disk. Files will be re-downloaded when needed."
      )
    }
    .alert("Clear Thumbnail", isPresented: $showClearThumbnailCacheConfirmation) {
      Button("Clear", role: .destructive) {
        Task {
          await CacheManager.clearThumbnailCache()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached thumbnails from memory and disk. Thumbnails will be re-downloaded when needed."
      )
    }
    .task {
      await loadCacheSize()
    }
    .onChange(of: maxDiskCacheSizeMB) {
      // Trigger cache cleanup when max cache size changes
      Task {
        await ImageCache.cleanupDiskCacheIfNeeded()
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
    imageCacheSize = await imageSize
    imageCacheCount = await imageCount
    bookFileCacheSize = await bookFileSize
    bookFileCacheCount = await bookFileCount
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
