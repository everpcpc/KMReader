//
// NativePagedReaderSession.swift
//
//

import Foundation

@MainActor
final class NativePagedReaderSession {
  struct SnapshotPlan {
    let anchor: ReaderViewItem?
    let commitAnchor: Bool
  }

  enum NavigationPlan {
    case none
    case refreshVisible
    case commit(ReaderViewItem)
    case scroll(ReaderViewItem)
    case applySnapshot(SnapshotPlan)
  }

  private(set) var renderedItems: [ReaderViewItem] = []
  private(set) var committedItem: ReaderViewItem?
  private(set) var hasSyncedInitialPosition = false
  private(set) var isUserInteracting = false
  private(set) var isProgrammaticScrolling = false

  private var pendingInitialItem: ReaderViewItem?
  private var pendingRenderedItems: [ReaderViewItem]?
  private var deferredAnchorItem: ReaderViewItem?
  private var pendingProgrammaticCommitItem: ReaderViewItem?

  var isInteractionActive: Bool {
    isUserInteracting || isProgrammaticScrolling
  }

  func teardown() {
    pendingRenderedItems = nil
    deferredAnchorItem = nil
    pendingProgrammaticCommitItem = nil
    pendingInitialItem = nil
    renderedItems.removeAll()
    committedItem = nil
    hasSyncedInitialPosition = false
    isUserInteracting = false
    isProgrammaticScrolling = false
  }

  func installInitialSnapshotIfNeeded(_ viewItems: [ReaderViewItem]) -> Bool {
    guard renderedItems.isEmpty else { return false }
    renderedItems = viewItems
    return true
  }

  func prepareInitialPositionIfNeeded(currentItem: ReaderViewItem?) -> ReaderViewItem? {
    guard !hasSyncedInitialPosition else { return nil }
    if let pendingInitialItem {
      return resolveAnchor(pendingInitialItem, in: renderedItems)
    }
    guard let currentItem else { return nil }
    let resolvedItem = resolveAnchor(currentItem, in: renderedItems)
    pendingInitialItem = resolvedItem
    return resolvedItem
  }

  func completeInitialPositionIfNeeded() -> ReaderViewItem? {
    guard !hasSyncedInitialPosition else { return nil }
    guard let pendingInitialItem = resolveAnchor(pendingInitialItem, in: renderedItems) else { return nil }
    self.pendingInitialItem = nil
    committedItem = pendingInitialItem
    hasSyncedInitialPosition = true
    return pendingInitialItem
  }

  func currentAnchor(
    fallbackCentered: ReaderViewItem?,
    fallbackCurrent: ReaderViewItem?
  ) -> ReaderViewItem? {
    committedItem ?? pendingInitialItem ?? fallbackCentered ?? fallbackCurrent
  }

  func setUserInteracting(_ isActive: Bool) -> Bool {
    guard isUserInteracting != isActive else { return false }
    isUserInteracting = isActive
    return true
  }

  func beginUserInteraction() -> Bool {
    setUserInteracting(true)
  }

  func endUserInteraction() -> Bool {
    setUserInteracting(false)
  }

  func handleViewItemsChange(_ newItems: [ReaderViewItem], anchor: ReaderViewItem?) -> SnapshotPlan? {
    if isInteractionActive {
      pendingRenderedItems = newItems
      deferredAnchorItem = anchor
      return nil
    }
    return makeSnapshotPlan(snapshot: newItems, anchor: anchor, commitAnchor: true)
  }

  func applyPendingSnapshotIfNeeded(anchorFallback: ReaderViewItem?) -> SnapshotPlan? {
    guard let pendingRenderedItems else { return nil }
    self.pendingRenderedItems = nil

    let anchor = deferredAnchorItem ?? anchorFallback
    deferredAnchorItem = nil
    return makeSnapshotPlan(snapshot: pendingRenderedItems, anchor: anchor, commitAnchor: true)
  }

  func navigationPlan(
    for targetItem: ReaderViewItem,
    centeredItem: ReaderViewItem?,
    latestViewItems: [ReaderViewItem]
  ) -> NavigationPlan {
    guard hasSyncedInitialPosition else {
      pendingInitialItem = resolveAnchor(targetItem, in: latestViewItems)
      return .none
    }

    if isProgrammaticScrolling, pendingProgrammaticCommitItem == targetItem {
      return .refreshVisible
    }

    if !renderedItems.contains(targetItem) {
      return .applySnapshot(
        makeSnapshotPlan(snapshot: latestViewItems, anchor: targetItem, commitAnchor: true)
      )
    }

    if centeredItem == targetItem {
      pendingProgrammaticCommitItem = nil
      return .commit(targetItem)
    }

    return .scroll(targetItem)
  }

  func beginProgrammaticScroll(to item: ReaderViewItem) {
    isProgrammaticScrolling = true
    pendingProgrammaticCommitItem = item
  }

  func endProgrammaticScroll() -> Bool {
    guard isProgrammaticScrolling else { return false }
    isProgrammaticScrolling = false
    return true
  }

  func consumePendingProgrammaticCommit() -> ReaderViewItem? {
    guard let pendingProgrammaticCommitItem else { return nil }
    self.pendingProgrammaticCommitItem = nil
    return resolveAnchor(pendingProgrammaticCommitItem, in: renderedItems)
  }

  func clearPendingProgrammaticCommit() {
    pendingProgrammaticCommitItem = nil
  }

  func commit(_ item: ReaderViewItem) {
    committedItem = item
  }

  private func makeSnapshotPlan(
    snapshot: [ReaderViewItem],
    anchor: ReaderViewItem?,
    commitAnchor: Bool
  ) -> SnapshotPlan {
    renderedItems = snapshot
    if let pendingInitialItem {
      self.pendingInitialItem = resolveAnchor(pendingInitialItem, in: snapshot)
    }

    guard let resolvedAnchor = resolveAnchor(anchor, in: snapshot) else {
      return SnapshotPlan(anchor: nil, commitAnchor: false)
    }

    return SnapshotPlan(
      anchor: resolvedAnchor,
      commitAnchor: commitAnchor
    )
  }

  private func resolveAnchor(
    _ anchor: ReaderViewItem?,
    in snapshot: [ReaderViewItem]
  ) -> ReaderViewItem? {
    guard let anchor else { return nil }

    if snapshot.contains(anchor) {
      return anchor
    }

    if let pageMatch = snapshot.first(where: { $0.pageID == anchor.pageID }) {
      return pageMatch
    }

    return snapshot.first
  }
}
