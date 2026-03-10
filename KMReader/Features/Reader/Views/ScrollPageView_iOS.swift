#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  struct ScrollPageView: UIViewRepresentable {
    let mode: PageViewMode
    let viewportSize: CGSize
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let navigationAnimationDuration: TimeInterval
    let renderConfig: ReaderRenderConfig
    @Bindable var viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void

    init(
      mode: PageViewMode,
      viewportSize: CGSize,
      readingDirection: ReadingDirection,
      splitWidePageMode: SplitWidePageMode,
      navigationAnimationDuration: TimeInterval = 0.3,
      renderConfig: ReaderRenderConfig,
      viewModel: ReaderViewModel,
      readListContext: ReaderReadListContext?,
      onDismiss: @escaping () -> Void
    ) {
      self.mode = mode
      self.viewportSize = viewportSize
      self.readingDirection = readingDirection
      self.splitWidePageMode = splitWidePageMode
      self.navigationAnimationDuration = navigationAnimationDuration
      self.renderConfig = renderConfig
      self.viewModel = viewModel
      self.readListContext = readListContext
      self.onDismiss = onDismiss
    }

    private var shouldDisableScrollInteraction: Bool {
      #if os(tvOS)
        true
      #else
        viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil
      #endif
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIView(context: Context) -> UICollectionView {
      let layout = UICollectionViewFlowLayout()
      layout.scrollDirection = mode.isVertical ? .vertical : .horizontal
      layout.minimumLineSpacing = 0
      layout.minimumInteritemSpacing = 0

      let collectionView = NativePagedLayoutAwareCollectionView(
        frame: .zero,
        collectionViewLayout: layout
      )
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      collectionView.showsHorizontalScrollIndicator = false
      collectionView.showsVerticalScrollIndicator = false
      collectionView.contentInsetAdjustmentBehavior = .never
      collectionView.bounces = false
      collectionView.isPrefetchingEnabled = false
      collectionView.semanticContentAttribute = .forceLeftToRight

      #if !os(tvOS)
        collectionView.isPagingEnabled = true
        collectionView.scrollsToTop = false
      #endif

      collectionView.register(
        NativePagedPageCell.self,
        forCellWithReuseIdentifier: Coordinator.pageCellReuseIdentifier
      )
      collectionView.register(
        NativePagedEndCell.self,
        forCellWithReuseIdentifier: Coordinator.endCellReuseIdentifier
      )

      context.coordinator.collectionView = collectionView
      collectionView.onDidLayout = { [weak coordinator = context.coordinator] in
        coordinator?.handleCollectionViewLayout()
      }
      return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
      context.coordinator.update(parent: self, collectionView: collectionView)
      collectionView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      collectionView.semanticContentAttribute = .forceLeftToRight
      collectionView.isScrollEnabled = !shouldDisableScrollInteraction
      if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
        let targetDirection: UICollectionView.ScrollDirection = mode.isVertical ? .vertical : .horizontal
        if layout.scrollDirection != targetDirection {
          layout.scrollDirection = targetDirection
          layout.invalidateLayout()
        }
      }
    }

    static func dismantleUIView(_ uiView: UICollectionView, coordinator: Coordinator) {
      coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
      UIScrollViewDelegate, NativePagedPagePresentationHost
    {
      private struct RenderInputs: Equatable {
        let readingDirection: ReadingDirection
        let splitWidePageMode: SplitWidePageMode
        let renderConfig: ReaderRenderConfig
        let readListContext: ReaderReadListContext?
      }

      static let pageCellReuseIdentifier = "NativePagedPageCell"
      static let endCellReuseIdentifier = "NativePagedEndCell"

      var parent: ScrollPageView
      weak var collectionView: UICollectionView?

      private let engine = ScrollReaderEngine()
      private let pagePresentationCoordinator = NativePagedPagePresentationCoordinator()
      private var lastViewportSize: CGSize = .zero
      private var lastRenderInputs: RenderInputs?
      private var deferredViewModelCommitTask: Task<Void, Never>?

      init(_ parent: ScrollPageView) {
        self.parent = parent
        super.init()
        pagePresentationCoordinator.host = self
      }

      func teardown() {
        deferredViewModelCommitTask?.cancel()
        deferredViewModelCommitTask = nil
        pagePresentationCoordinator.teardown()
        engine.teardown()
      }

      func update(parent: ScrollPageView, collectionView: UICollectionView) {
        self.parent = parent
        self.collectionView = collectionView
        pagePresentationCoordinator.update(viewModel: parent.viewModel)

        let displayedItems = parent.mode.displayOrderedItems(parent.viewModel.viewItems)
        let anchorItem = currentAnchorItem(in: collectionView)
        let sizeChanged = updateLayoutIfNeeded(for: collectionView)
        let renderInputsChanged = updateRenderInputsIfNeeded()
        var refreshedVisibleContent = false

        if engine.installInitialItemsIfNeeded(displayedItems) {
          collectionView.reloadData()
          collectionView.layoutIfNeeded()
          refreshedVisibleContent = synchronizeInitialPositionIfPossible(in: collectionView)
        } else if displayedItems != engine.renderedItems {
          if engine.isInteractionActive {
            engine.queueRenderedItems(displayedItems, anchor: anchorItem)
          } else {
            applyRenderedItems(
              displayedItems,
              anchor: anchorItem,
              commitAfterRestore: parent.viewModel.navigationTarget == nil,
              in: collectionView
            )
          }
          refreshedVisibleContent = true
        }

        if engine.hasSyncedInitialPosition, sizeChanged, !refreshedVisibleContent {
          if let anchorItem {
            scrollToItem(anchorItem, animated: false, in: collectionView)
            refreshVisibleCells(in: collectionView)
            if parent.viewModel.navigationTarget == nil {
              commitRestoredItemIfNeeded(anchor: anchorItem, in: collectionView)
            }
            refreshedVisibleContent = true
          }
        }

        if let navigationTarget = parent.viewModel.navigationTarget {
          handleNavigationChange(navigationTarget, in: collectionView)
        } else if renderInputsChanged && !refreshedVisibleContent {
          refreshVisibleCells(in: collectionView)
        }

        pagePresentationCoordinator.flushIfPossible()
      }

      private func updateRenderInputsIfNeeded() -> Bool {
        let renderInputs = RenderInputs(
          readingDirection: parent.readingDirection,
          splitWidePageMode: parent.splitWidePageMode,
          renderConfig: parent.renderConfig,
          readListContext: parent.readListContext
        )
        let changed = lastRenderInputs != renderInputs
        lastRenderInputs = renderInputs
        return changed
      }

      private func updateLayoutIfNeeded(for collectionView: UICollectionView) -> Bool {
        let viewportSize = resolvedViewportSize(for: collectionView)
        guard viewportSize.width > 0, viewportSize.height > 0 else { return false }

        let sizeChanged = viewportSize != lastViewportSize
        lastViewportSize = viewportSize

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
          layout.itemSize != viewportSize
        {
          layout.itemSize = viewportSize
          layout.invalidateLayout()
        }

        return sizeChanged
      }

      private func resolvedViewportSize(for collectionView: UICollectionView) -> CGSize {
        let boundsSize = collectionView.bounds.size
        // The reader content ignores safe area, so the visible collection view bounds
        // are the only reliable paging viewport after layout.
        if boundsSize.width > 0, boundsSize.height > 0 {
          return boundsSize
        }
        return parent.viewportSize
      }

      private func canApplyInitialPosition(in collectionView: UICollectionView) -> Bool {
        let boundsSize = collectionView.bounds.size
        return collectionView.window != nil && boundsSize.width > 0 && boundsSize.height > 0
      }

      @discardableResult
      private func synchronizeInitialPositionIfPossible(in collectionView: UICollectionView) -> Bool {
        guard
          let currentItem = engine.prepareInitialPosition(
            currentItem: parent.viewModel.currentViewItem()
          )
        else {
          return false
        }
        guard canApplyInitialPosition(in: collectionView) else { return false }

        scrollToItem(currentItem, animated: false, in: collectionView)
        guard let committedItem = engine.completeInitialPosition() else { return false }
        preloadVisiblePages(for: committedItem)
        refreshVisibleCells(in: collectionView)
        if parent.viewModel.navigationTarget == nil {
          scheduleViewModelCommit(for: committedItem)
        }
        return true
      }

      func handleCollectionViewLayout() {
        guard let collectionView else { return }
        if synchronizeInitialPositionIfPossible(in: collectionView) {
          pagePresentationCoordinator.flushIfPossible()
        }
      }

      private func applyRenderedItems(
        _ items: [ReaderViewItem],
        anchor: ReaderViewItem?,
        commitAfterRestore: Bool,
        in collectionView: UICollectionView
      ) {
        engine.replaceRenderedItems(items)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if let anchor = engine.resolveItem(anchor) {
          scrollToItem(anchor, animated: false, in: collectionView)
        }

        refreshVisibleCells(in: collectionView)
        if commitAfterRestore {
          commitRestoredItemIfNeeded(anchor: anchor, in: collectionView)
        }
      }

      @discardableResult
      private func applyQueuedRenderedItemsIfNeeded(in collectionView: UICollectionView) -> Bool {
        guard let update = engine.consumeQueuedRenderedItems(anchorFallback: currentAnchorItem(in: collectionView))
        else {
          return false
        }

        applyRenderedItems(
          update.items,
          anchor: update.anchor,
          commitAfterRestore: parent.viewModel.navigationTarget == nil,
          in: collectionView
        )
        return true
      }

      private func handleNavigationChange(
        _ navigationTarget: ReaderViewItem,
        in collectionView: UICollectionView
      ) {
        guard let resolvedTarget = parent.viewModel.resolvedViewItem(for: navigationTarget),
          let targetItem = engine.resolveItem(resolvedTarget)
        else {
          parent.viewModel.clearNavigationTarget()
          return
        }

        guard engine.hasSyncedInitialPosition else {
          engine.setPendingInitialItem(targetItem)
          return
        }

        if engine.isProgrammaticScrolling && engine.isPendingProgrammaticCommit(targetItem) {
          refreshVisibleCells(in: collectionView)
          return
        }

        if centeredItem(in: collectionView) == targetItem {
          engine.clearPendingProgrammaticCommit()
          commitItemIfNeeded(targetItem, in: collectionView)
          return
        }

        scrollToItem(targetItem, animated: true, in: collectionView)
      }

      private func scrollToItem(
        _ item: ReaderViewItem,
        animated: Bool,
        in collectionView: UICollectionView
      ) {
        guard let index = engine.renderedItems.firstIndex(of: item) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.layoutIfNeeded()
        guard let targetOffset = targetContentOffset(for: indexPath, in: collectionView) else {
          return
        }

        if isEquivalentContentOffset(targetOffset, to: collectionView.contentOffset) {
          engine.clearPendingProgrammaticCommit()
          refreshVisibleCells(in: collectionView)
          if animated {
            commitItemIfNeeded(item, in: collectionView)
          }
          return
        }

        let shouldAnimate = animated && parent.navigationAnimationDuration > 0

        if shouldAnimate {
          engine.beginProgrammaticScroll(to: item)
          preloadVisiblePages(for: item)
          collectionView.setContentOffset(targetOffset, animated: true)
        } else {
          engine.clearPendingProgrammaticCommit()
          collectionView.setContentOffset(targetOffset, animated: false)
          refreshVisibleCells(in: collectionView)
          if animated {
            commitItemIfNeeded(item, in: collectionView)
          }
        }
      }

      private func targetContentOffset(
        for indexPath: IndexPath,
        in collectionView: UICollectionView
      ) -> CGPoint? {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
          return nil
        }

        let proposedOffset = CGPoint(
          x: parent.mode.isVertical ? collectionView.contentOffset.x : attributes.frame.minX,
          y: parent.mode.isVertical ? attributes.frame.minY : collectionView.contentOffset.y
        )
        return clampedContentOffset(proposedOffset, in: collectionView)
      }

      private func clampedContentOffset(
        _ proposedOffset: CGPoint,
        in collectionView: UICollectionView
      ) -> CGPoint {
        let inset = collectionView.adjustedContentInset
        let minX = -inset.left
        let minY = -inset.top
        let maxX = max(
          minX,
          collectionView.contentSize.width - collectionView.bounds.width + inset.right
        )
        let maxY = max(
          minY,
          collectionView.contentSize.height - collectionView.bounds.height + inset.bottom
        )

        return CGPoint(
          x: min(max(proposedOffset.x, minX), maxX),
          y: min(max(proposedOffset.y, minY), maxY)
        )
      }

      private func isEquivalentContentOffset(_ lhs: CGPoint, to rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) < 0.5 && abs(lhs.y - rhs.y) < 0.5
      }

      private func currentAnchorItem(in collectionView: UICollectionView) -> ReaderViewItem? {
        centeredItem(in: collectionView)
          ?? parent.viewModel.currentViewItem()
          ?? engine.committedItem
      }

      private func centeredItem(in collectionView: UICollectionView) -> ReaderViewItem? {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return engine.committedItem }

        let center = CGPoint(
          x: collectionView.contentOffset.x + collectionView.bounds.midX,
          y: collectionView.contentOffset.y + collectionView.bounds.midY
        )

        let nearestIndexPath = visibleIndexPaths.min { lhs, rhs in
          let lhsDistance = distanceFromCenter(of: lhs, to: center, in: collectionView)
          let rhsDistance = distanceFromCenter(of: rhs, to: center, in: collectionView)
          return lhsDistance < rhsDistance
        }

        guard let nearestIndexPath, let item = renderedItem(at: nearestIndexPath.item) else {
          return engine.committedItem
        }
        return item
      }

      private func distanceFromCenter(
        of indexPath: IndexPath,
        to center: CGPoint,
        in collectionView: UICollectionView
      ) -> CGFloat {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
          return .greatestFiniteMagnitude
        }
        let dx = attributes.center.x - center.x
        let dy = attributes.center.y - center.y
        return sqrt(dx * dx + dy * dy)
      }

      private func commitCenteredItem(in collectionView: UICollectionView) {
        guard let item = centeredItem(in: collectionView) else { return }
        commitItemIfNeeded(item, in: collectionView)
      }

      private func commitRestoredItemIfNeeded(
        anchor: ReaderViewItem?,
        in collectionView: UICollectionView
      ) {
        if let item = engine.resolveItem(anchor) {
          commitItemIfNeeded(item, in: collectionView)
          return
        }
        commitCenteredItem(in: collectionView)
      }

      private func commitPendingProgrammaticItemIfNeeded(in collectionView: UICollectionView) -> Bool {
        guard let resolvedItem = engine.consumePendingProgrammaticCommit() else {
          return false
        }
        commitItemIfNeeded(resolvedItem, in: collectionView)
        return true
      }

      private func commitItemIfNeeded(_ item: ReaderViewItem, in collectionView: UICollectionView) {
        let previousCommittedItem = engine.committedItem
        engine.commit(item)
        preloadVisiblePages(for: item)
        refreshCommittedPlaybackState(
          from: previousCommittedItem,
          to: item,
          in: collectionView
        )
        scheduleViewModelCommit(for: item)
      }

      private func refreshVisibleCells(
        in collectionView: UICollectionView,
        matching pageIDs: Set<ReaderPageID>? = nil
      ) {
        for cell in collectionView.visibleCells {
          guard let indexPath = collectionView.indexPath(for: cell),
            let item = renderedItem(at: indexPath.item)
          else {
            continue
          }
          if let pageIDs, !item.pageIDs.contains(where: pageIDs.contains) {
            continue
          }
          configureCell(cell, at: indexPath.item, in: collectionView)
        }
      }

      func hasVisiblePagePresentationContent() -> Bool {
        guard let collectionView else { return false }
        return !collectionView.visibleCells.isEmpty
      }

      func applyPagePresentationInvalidation(_ invalidation: ReaderPagePresentationInvalidation) {
        guard let collectionView else { return }

        switch invalidation {
        case .all:
          refreshVisibleCells(in: collectionView)
        case .pages(let pageIDs):
          refreshVisibleCells(in: collectionView, matching: pageIDs)
        }
      }

      private func renderedItem(at index: Int) -> ReaderViewItem? {
        guard engine.renderedItems.indices.contains(index) else { return nil }
        return engine.renderedItems[index]
      }

      private func fallbackCell(
        for indexPath: IndexPath,
        in collectionView: UICollectionView
      ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: Self.pageCellReuseIdentifier,
          for: indexPath
        )
        if let pageCell = cell as? NativePagedPageCell {
          pageCell.resetContent(backgroundColor: UIColor(parent.renderConfig.readerBackground.color))
        }
        return cell
      }

      private func configureCell(
        _ cell: UICollectionViewCell,
        at index: Int,
        in collectionView: UICollectionView
      ) {
        guard let item = renderedItem(at: index) else { return }

        if item.isEnd {
          guard let endCell = cell as? NativePagedEndCell else { return }
          let segmentBookId = item.pageID.bookId
          endCell.configure(
            previousBook: parent.viewModel.currentBook(forSegmentBookId: segmentBookId),
            nextBook: parent.viewModel.nextBook(forSegmentBookId: segmentBookId),
            readListContext: parent.readListContext,
            readingDirection: parent.readingDirection,
            renderConfig: parent.renderConfig,
            onDismiss: parent.onDismiss
          )
          return
        }

        guard let pageCell = cell as? NativePagedPageCell else { return }
        pageCell.backgroundColor = UIColor(parent.renderConfig.readerBackground.color)
        pageCell.configure(
          viewModel: parent.viewModel,
          item: item,
          screenSize: resolvedViewportSize(for: collectionView),
          renderConfig: parent.renderConfig,
          readingDirection: parent.readingDirection,
          splitWidePageMode: parent.splitWidePageMode,
          isPlaybackActive: item == engine.committedItem
        )
      }

      private func refreshCommittedPlaybackState(
        from previousItem: ReaderViewItem?,
        to currentItem: ReaderViewItem,
        in collectionView: UICollectionView
      ) {
        guard previousItem != currentItem else { return }

        for cell in collectionView.visibleCells {
          guard let indexPath = collectionView.indexPath(for: cell),
            let item = renderedItem(at: indexPath.item),
            let pageCell = cell as? NativePagedPageCell
          else {
            continue
          }

          guard item == previousItem || item == currentItem else { continue }
          pageCell.updatePlaybackActive(item == currentItem)
        }
      }

      private func scheduleViewModelCommit(for item: ReaderViewItem) {
        guard parent.viewModel.currentViewItem() != item || parent.viewModel.navigationTarget != nil else {
          return
        }

        deferredViewModelCommitTask?.cancel()
        deferredViewModelCommitTask = Task { @MainActor [weak self] in
          await Task.yield()
          guard let self, self.engine.committedItem == item else { return }

          if self.parent.viewModel.currentViewItem() != item {
            self.parent.viewModel.updateCurrentPosition(viewItem: item)
          }
          if self.parent.viewModel.navigationTarget != nil {
            self.parent.viewModel.clearNavigationTarget()
          }
        }
      }

      private func preloadVisiblePages(for item: ReaderViewItem) {
        let visiblePageIndices = item.pageIDs.compactMap { parent.viewModel.pageIndex(for: $0) }
        guard !visiblePageIndices.isEmpty else { return }

        Task(priority: .userInitiated) {
          for pageIndex in visiblePageIndices {
            _ = await parent.viewModel.preloadImageForPage(at: pageIndex)
          }
        }
      }

      private func finishScrollInteractionIfNeeded() {
        guard let collectionView else { return }

        _ = engine.endUserInteraction()
        engine.clearPendingProgrammaticCommit()
        let appliedQueuedItems = applyQueuedRenderedItemsIfNeeded(in: collectionView)
        if !appliedQueuedItems, parent.viewModel.navigationTarget == nil {
          commitCenteredItem(in: collectionView)
        }
      }

      private func finishProgrammaticScroll(in collectionView: UICollectionView) {
        _ = engine.endProgrammaticScroll()
        let appliedQueuedItems = applyQueuedRenderedItemsIfNeeded(in: collectionView)
        if !commitPendingProgrammaticItemIfNeeded(in: collectionView) {
          if !appliedQueuedItems, parent.viewModel.navigationTarget == nil {
            commitCenteredItem(in: collectionView)
          }
        }
      }

      func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        engine.renderedItems.count
      }

      func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
      ) -> UICollectionViewCell {
        guard let item = renderedItem(at: indexPath.item) else {
          return fallbackCell(for: indexPath, in: collectionView)
        }

        if item.isEnd {
          let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.endCellReuseIdentifier,
            for: indexPath
          )
          configureCell(cell, at: indexPath.item, in: collectionView)
          return cell
        }

        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: Self.pageCellReuseIdentifier,
          for: indexPath
        )
        configureCell(cell, at: indexPath.item, in: collectionView)
        return cell
      }

      func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
      ) {
        pagePresentationCoordinator.flushIfPossible()
      }

      func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> CGSize {
        resolvedViewportSize(for: collectionView)
      }

      func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        _ = engine.beginUserInteraction()
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView else { return }
        if let item = centeredItem(in: collectionView) {
          preloadVisiblePages(for: item)
        }
      }

      func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
          finishScrollInteractionIfNeeded()
        }
      }

      func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finishScrollInteractionIfNeeded()
      }

      func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard let collectionView else { return }
        finishProgrammaticScroll(in: collectionView)
      }
    }
  }
#endif
