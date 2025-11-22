//
//  SettingsCacheView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsCacheView: View {
  @AppStorage("maxDiskCacheSizeMB") private var maxDiskCacheSizeMB: Int = 2048
  @State private var showClearCacheConfirmation = false
  @State private var diskCacheSize: Int64 = 0
  @State private var diskCacheCount: Int = 0
  @State private var isLoadingCacheSize = false

  private var maxCacheSizeBinding: Binding<Double> {
    Binding(
      get: { Double(maxDiskCacheSizeMB) },
      set: { maxDiskCacheSizeMB = Int($0) }
    )
  }

  var body: some View {
    List {
      Section(header: Text("Page Cache")) {
        VStack(alignment: .leading, spacing: 8) {
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
            Text(formatCacheSize(diskCacheSize))
              .foregroundColor(.secondary)
          }
        }

        HStack {
          Text("Cached Images")
          Spacer()
          if isLoadingCacheSize {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text(formatCacheCount(diskCacheCount))
              .foregroundColor(.secondary)
          }
        }

        Button(role: .destructive) {
          showClearCacheConfirmation = true
        } label: {
          HStack {
            Spacer()
            Text("Clear Disk Cache")
            Spacer()
          }
        }
      }
    }
    .navigationTitle("Cache")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Clear Disk Cache", isPresented: $showClearCacheConfirmation) {
      Button("Clear Cache", role: .destructive) {
        Task {
          await ImageCache.clearAllDiskCache()
          await loadCacheSize()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This will remove all cached images from disk. Images will be re-downloaded when needed.")
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
    async let size = ImageCache.getDiskCacheSize()
    async let count = ImageCache.getDiskCacheCount()
    diskCacheSize = await size
    diskCacheCount = await count
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
