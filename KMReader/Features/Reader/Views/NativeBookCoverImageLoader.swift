//
// NativeBookCoverImageLoader.swift
//
//

import Foundation

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

func loadNativeBookCoverImage(for bookID: String) async -> PlatformImage? {
  await Task.detached(priority: .userInitiated) {
    let targetURL = try? await ThumbnailCache.shared.ensureThumbnail(id: bookID, type: .book)

    guard !Task.isCancelled, let targetURL else { return nil }
    guard let image = PlatformImage(contentsOfFile: targetURL.path) else { return nil }
    return await ImageDecodeHelper.decodeForDisplay(image)
  }
  .value
}
