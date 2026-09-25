//
// CoverArtworkLoadingModifier.swift
//
//

import SwiftUI

/// Loads the downscaled cover behind a `CoverTintedCardBackground`, and reloads
/// it when the book's thumbnail is refreshed.
struct CoverArtworkLoadingModifier: ViewModifier {
  let instanceId: String
  let bookId: String
  @Binding var artwork: PlatformImage?

  func body(content: Content) -> some View {
    content
      .task(id: bookId) {
        artwork = await CoverBackgroundProvider.shared.backgroundImage(
          instanceId: instanceId, id: bookId, type: .book)
      }
      .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidRefresh)) { notification in
        guard let userInfo = notification.userInfo,
          let id = userInfo["id"] as? String,
          let type = userInfo["type"] as? String,
          id == bookId,
          type == ThumbnailType.book.rawValue
        else { return }
        Task {
          await CoverBackgroundProvider.shared.invalidate(
            instanceId: instanceId, id: bookId, type: .book)
          artwork = await CoverBackgroundProvider.shared.backgroundImage(
            instanceId: instanceId, id: bookId, type: .book)
        }
      }
  }
}

extension View {
  func coverArtwork(instanceId: String, bookId: String, into artwork: Binding<PlatformImage?>) -> some View {
    modifier(CoverArtworkLoadingModifier(instanceId: instanceId, bookId: bookId, artwork: artwork))
  }
}
