//
// OnDeckReadListMerge.swift
//
//

import Foundation

/// Folds the read lists being read into On Deck for one view (the dashboard row
/// or its detail page) and remembers which read lists it merged, so the view
/// reloads when they change on their own schedule: a sync, another device,
/// Stop Reading. The merge rule itself is `ReadListReadingSnapshot.mergingOnDeck`.
@MainActor
final class OnDeckReadListMerge {
  private var mergedSnapshot: ReadListReadingSnapshot?
  private let logger = AppLogger(.dashboard)

  /// The first page merges the latest read lists; later pages reuse them so
  /// pages stay consistent until a reload. Sections other than On Deck pass
  /// through unchanged.
  func merge(
    _ ids: [String],
    in section: DashboardSection,
    isFirstPage: Bool,
    libraryIds: [String]
  ) async -> [String] {
    guard section.mergesReadListContinuations else { return ids }
    let snapshot: ReadListReadingSnapshot
    if isFirstPage {
      snapshot = await ReadListReadingService.shared.refreshSnapshot()
      mergedSnapshot = snapshot
    } else {
      snapshot = mergedSnapshot ?? .empty
    }
    return snapshot.mergingOnDeck(ids, libraryIds: libraryIds, isFirstPage: isFirstPage)
  }

  /// Runs `reload` when the view shows read lists older than `snapshot`. A view
  /// that has not merged yet, or is loading, merges the latest ones itself.
  func reloadIfOutdated(by snapshot: ReadListReadingSnapshot?, isLoading: Bool, reload: () -> Void) {
    guard let snapshot, !isLoading, let mergedSnapshot, mergedSnapshot != snapshot else { return }
    logger.debug("On Deck reloading: read lists changed")
    reload()
  }
}
