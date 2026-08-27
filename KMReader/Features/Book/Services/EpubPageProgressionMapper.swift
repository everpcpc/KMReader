//
// EpubPageProgressionMapper.swift
//
//

import Foundation

/// Maps a page-based server read progress to a Readium progression using the
/// WebPub positions endpoint. Used when the server stores page-based progress
/// (KOReader/Kindle sync, paged readers, web UI) and the progression endpoint
/// answers with an empty locator. Returns nil when the page cannot be mapped,
/// in which case callers must treat the position as unknown rather than
/// falling back to the first page.
enum EpubPageProgressionMapper {
  static let logger = AppLogger(.reader)

  static func progression(bookId: String, page: Int) async -> R2Progression? {
    guard !AppConfig.isOffline else { return nil }

    let positions: R2Positions
    do {
      positions = try await BookService.getWebPubPositions(bookId: bookId)
    } catch {
      logger.warning(
        "⚠️ [Progress/Epub] Failed to fetch positions for page-based mapping: book=\(bookId), error=\(error.localizedDescription)"
      )
      return nil
    }

    let candidates = positions.positions.compactMap { locator -> (position: Int, locator: R2Locator)? in
      guard let position = locator.locations?.position else { return nil }
      return (position, locator)
    }
    guard !candidates.isEmpty else { return nil }

    let sorted = candidates.sorted { $0.position < $1.position }
    guard let match = sorted.last(where: { $0.position <= page }) ?? sorted.first else {
      return nil
    }

    return R2Progression(
      modified: Date(),
      device: R2Device(
        id: AppConfig.deviceIdentifier,
        name: AppConfig.userAgent
      ),
      locator: match.locator
    )
  }
}
