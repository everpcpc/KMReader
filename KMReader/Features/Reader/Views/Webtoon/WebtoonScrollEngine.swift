//
// WebtoonScrollEngine.swift
//

import Foundation

@MainActor
final class WebtoonScrollEngine {
  var currentPage: Int
  var currentPageID: ReaderPageID?
  var pendingReloadCurrentPageID: ReaderPageID?
  var hasScrolledToInitialPage: Bool = false

  private(set) var contentItems: [WebtoonContentItems.Item] = []
  private(set) var itemIndexByPageID: [ReaderPageID: Int] = [:]

  private var contentItemsVersion: Int = -1
  private var initialScrollRetrier: InitialScrollRetrier
  private var initialScrollGeneration: Int = 0

  init(
    initialPage: Int,
    initialPageID: ReaderPageID?,
    maxInitialScrollRetries: Int = WebtoonConstants.initialScrollMaxRetries
  ) {
    currentPage = initialPage
    currentPageID = initialPageID
    initialScrollRetrier = InitialScrollRetrier(maxRetries: maxInitialScrollRetries)
  }

  var itemCount: Int {
    contentItems.count
  }

  @discardableResult
  func rebuildContentItemsIfNeeded(viewModel: ReaderViewModel?) -> Bool {
    guard let viewModel else {
      let didChange = !contentItems.isEmpty || !itemIndexByPageID.isEmpty
      contentItems = []
      itemIndexByPageID = [:]
      contentItemsVersion = -1
      return didChange
    }

    let version = viewModel.readerPagesVersion
    guard version != contentItemsVersion else { return false }

    let snapshot = WebtoonContentItems.build(from: viewModel)
    let didChange = snapshot.items != contentItems
    contentItems = snapshot.items
    itemIndexByPageID = snapshot.itemIndexByPageID
    contentItemsVersion = version
    return didChange
  }

  func pageID(forPageIndex pageIndex: Int, viewModel: ReaderViewModel?) -> ReaderPageID? {
    viewModel?.readerPage(at: pageIndex)?.id
  }

  func pageIndex(forPageID pageID: ReaderPageID?, viewModel: ReaderViewModel?) -> Int? {
    guard let pageID else { return nil }
    return viewModel?.pageIndex(for: pageID)
  }

  func itemIndex(forPageID pageID: ReaderPageID?) -> Int? {
    guard let pageID else { return nil }
    return itemIndexByPageID[pageID]
  }

  func resolvedPageIndex(forItemIndex itemIndex: Int, viewModel: ReaderViewModel?) -> Int? {
    WebtoonContentItems.resolvedPageIndex(
      for: itemIndex,
      in: contentItems,
      viewModel: viewModel
    )
  }

  func resetInitialScrollRetrier() {
    initialScrollRetrier.reset()
    initialScrollGeneration &+= 1
  }

  func scheduleInitialScroll(
    currentPageID: ReaderPageID?,
    schedule: @escaping InitialScrollRetrier.DelayScheduler,
    canScrollToPageID: @escaping (ReaderPageID?) -> Bool,
    perform: @escaping (ReaderPageID?) -> Void
  ) {
    resetInitialScrollRetrier()
    requestInitialScroll(
      currentPageID,
      delay: WebtoonConstants.initialScrollDelay,
      schedule: schedule,
      canScrollToPageID: canScrollToPageID,
      perform: perform
    )
  }

  func requestInitialScroll(
    _ pageID: ReaderPageID?,
    delay: TimeInterval,
    schedule: @escaping InitialScrollRetrier.DelayScheduler,
    canScrollToPageID: @escaping (ReaderPageID?) -> Bool,
    perform: @escaping (ReaderPageID?) -> Void
  ) {
    let scheduledGeneration = initialScrollGeneration
    initialScrollRetrier.schedule(after: delay, using: schedule) { [weak self] in
      guard let self,
        scheduledGeneration == self.initialScrollGeneration,
        !self.hasScrolledToInitialPage,
        canScrollToPageID(pageID)
      else { return }
      perform(pageID)
    }
  }
}
