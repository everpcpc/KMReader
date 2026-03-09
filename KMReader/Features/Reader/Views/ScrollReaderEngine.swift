//
// ScrollReaderEngine.swift
//
//

import Foundation

@MainActor
final class ScrollReaderEngine {
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
    pendingInitialItem = nil
    pendingRenderedItems = nil
    deferredAnchorItem = nil
    pendingProgrammaticCommitItem = nil
    renderedItems.removeAll()
    committedItem = nil
    hasSyncedInitialPosition = false
    isUserInteracting = false
    isProgrammaticScrolling = false
  }

  func installInitialItemsIfNeeded(_ items: [ReaderViewItem]) -> Bool {
    guard renderedItems.isEmpty else { return false }
    replaceRenderedItems(items)
    return true
  }

  func replaceRenderedItems(_ items: [ReaderViewItem]) {
    renderedItems = items
    pendingInitialItem = resolveItem(pendingInitialItem, in: items)
    pendingProgrammaticCommitItem = resolveItem(pendingProgrammaticCommitItem, in: items)
    committedItem = resolveItem(committedItem, in: items)
  }

  func queueRenderedItems(_ items: [ReaderViewItem], anchor: ReaderViewItem?) {
    pendingRenderedItems = items
    deferredAnchorItem = resolveItem(anchor, in: items)
  }

  func consumeQueuedRenderedItems(anchorFallback: ReaderViewItem?) -> (
    items: [ReaderViewItem], anchor: ReaderViewItem?
  )? {
    guard let pendingRenderedItems else { return nil }
    self.pendingRenderedItems = nil
    let anchor = deferredAnchorItem ?? resolveItem(anchorFallback, in: pendingRenderedItems)
    deferredAnchorItem = nil
    replaceRenderedItems(pendingRenderedItems)
    return (pendingRenderedItems, anchor)
  }

  func prepareInitialPosition(currentItem: ReaderViewItem?) -> ReaderViewItem? {
    guard !hasSyncedInitialPosition else { return nil }
    if let pendingInitialItem {
      return resolveItem(pendingInitialItem)
    }
    guard let currentItem else { return nil }
    let resolvedItem = resolveItem(currentItem)
    pendingInitialItem = resolvedItem
    return resolvedItem
  }

  func setPendingInitialItem(_ item: ReaderViewItem?) {
    pendingInitialItem = resolveItem(item)
  }

  func completeInitialPosition() -> ReaderViewItem? {
    guard !hasSyncedInitialPosition else { return nil }
    guard let item = resolveItem(pendingInitialItem) else { return nil }
    pendingInitialItem = nil
    committedItem = item
    hasSyncedInitialPosition = true
    return item
  }

  func resolveItem(_ item: ReaderViewItem?) -> ReaderViewItem? {
    resolveItem(item, in: renderedItems)
  }

  func beginUserInteraction() -> Bool {
    guard !isUserInteracting else { return false }
    isUserInteracting = true
    return true
  }

  func endUserInteraction() -> Bool {
    guard isUserInteracting else { return false }
    isUserInteracting = false
    return true
  }

  func beginProgrammaticScroll(to item: ReaderViewItem) {
    isProgrammaticScrolling = true
    pendingProgrammaticCommitItem = resolveItem(item)
  }

  func endProgrammaticScroll() -> Bool {
    guard isProgrammaticScrolling else { return false }
    isProgrammaticScrolling = false
    return true
  }

  func consumePendingProgrammaticCommit() -> ReaderViewItem? {
    guard let pendingProgrammaticCommitItem else { return nil }
    self.pendingProgrammaticCommitItem = nil
    return resolveItem(pendingProgrammaticCommitItem)
  }

  func clearPendingProgrammaticCommit() {
    pendingProgrammaticCommitItem = nil
  }

  func isPendingProgrammaticCommit(_ item: ReaderViewItem) -> Bool {
    resolveItem(item) == pendingProgrammaticCommitItem
  }

  func commit(_ item: ReaderViewItem) {
    committedItem = resolveItem(item)
  }

  private func resolveItem(
    _ item: ReaderViewItem?,
    in snapshot: [ReaderViewItem]
  ) -> ReaderViewItem? {
    guard let item else { return nil }

    if snapshot.contains(item) {
      return item
    }

    if let pageMatch = snapshot.first(where: { $0.pageID == item.pageID }) {
      return pageMatch
    }

    return snapshot.first
  }
}
