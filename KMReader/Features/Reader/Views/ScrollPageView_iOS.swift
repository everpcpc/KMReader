#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  struct ScrollPageView: UIViewRepresentable {
    let mode: PageViewMode
    let viewportSize: CGSize
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    @Bindable var viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void

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

      let collectionView = NativePagedLayoutAwareCollectionView(frame: .zero, collectionViewLayout: layout)
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      collectionView.showsHorizontalScrollIndicator = false
      collectionView.showsVerticalScrollIndicator = false
      collectionView.contentInsetAdjustmentBehavior = .never
      collectionView.bounces = false
      collectionView.isPrefetchingEnabled = false
      // Keep collection coordinates canonical. RTL is represented by display order, not container mirroring.
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

      private let session = NativePagedReaderSession()
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
        session.teardown()
      }

      func update(parent: ScrollPageView, collectionView: UICollectionView) {
        self.parent = parent
        self.collectionView = collectionView
        pagePresentationCoordinator.update(viewModel: parent.viewModel)
        let displayedItems = parent.mode.displayOrderedItems(parent.viewModel.viewItems)

        let sizeChanged = updateLayoutIfNeeded(for: collectionView)
        let renderInputsChanged = updateRenderInputsIfNeeded()
        var refreshedVisibleContent = false

        if session.installInitialSnapshotIfNeeded(displayedItems) {
          collectionView.reloadData()
          collectionView.layoutIfNeeded()
          refreshedVisibleContent = synchronizeInitialPositionIfPossible(in: collectionView)
        } else if displayedItems != session.renderedItems {
          handleViewItemsChange(displayedItems, in: collectionView)
          refreshedVisibleContent = true
        }

        if session.hasSyncedInitialPosition, sizeChanged, let anchor = currentAnchorItem(in: collectionView) {
          scrollToItem(anchor, animated: false, in: collectionView)
          refreshedVisibleContent = true
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
        if parent.viewportSize.width > 0, parent.viewportSize.height > 0 {
          return parent.viewportSize
        }
        return collectionView.bounds.size
      }

      private func canApplyInitialPosition(in collectionView: UICollectionView) -> Bool {
        let boundsSize = collectionView.bounds.size
        return collectionView.window != nil && boundsSize.width > 0 && boundsSize.height > 0
      }

      @discardableResult
      private func synchronizeInitialPositionIfPossible(in collectionView: UICollectionView) -> Bool {
        guard
          let currentItem = session.prepareInitialPositionIfNeeded(
            currentItem: parent.viewModel.currentViewItem()
          )
        else {
          return false
        }
        guard canApplyInitialPosition(in: collectionView) else { return false }

        scrollToItem(currentItem, animated: false, in: collectionView)
        guard let committedItem = session.completeInitialPositionIfNeeded() else { return false }
        preloadVisiblePages(for: committedItem)
        refreshVisibleCells(in: collectionView)
        scheduleViewModelCommit(for: committedItem)
        return true
      }

      func handleCollectionViewLayout() {
        guard let collectionView else { return }
        if synchronizeInitialPositionIfPossible(in: collectionView) {
          pagePresentationCoordinator.flushIfPossible()
        }
      }

      private func handleViewItemsChange(_ newItems: [ReaderViewItem], in collectionView: UICollectionView) {
        guard
          let plan = session.handleViewItemsChange(
            newItems,
            anchor: currentAnchorItem(in: collectionView)
          )
        else {
          return
        }

        applySnapshotPlan(plan, in: collectionView)
      }

      @discardableResult
      private func applyPendingSnapshotIfNeeded(in collectionView: UICollectionView) -> Bool {
        guard
          let plan = session.applyPendingSnapshotIfNeeded(
            anchorFallback: currentAnchorItem(in: collectionView)
          )
        else {
          return false
        }

        applySnapshotPlan(plan, in: collectionView)
        return plan.commitAnchor && plan.anchor != nil
      }

      private func applySnapshotPlan(
        _ plan: NativePagedReaderSession.SnapshotPlan,
        in collectionView: UICollectionView
      ) {
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        guard let anchor = plan.anchor else {
          refreshVisibleCells(in: collectionView)
          return
        }

        scrollToItem(anchor, animated: false, in: collectionView)
        if plan.commitAnchor {
          commitItemIfNeeded(anchor, in: collectionView)
        } else {
          refreshVisibleCells(in: collectionView)
        }
      }

      private func handleNavigationChange(
        _ navigationTarget: ReaderViewItem,
        in collectionView: UICollectionView
      ) {
        guard let targetItem = parent.viewModel.resolvedViewItem(for: navigationTarget) else {
          parent.viewModel.clearNavigationTarget()
          return
        }

        switch session.navigationPlan(
          for: targetItem,
          centeredItem: centeredItem(in: collectionView),
          latestViewItems: parent.mode.displayOrderedItems(parent.viewModel.viewItems)
        ) {
        case .none:
          return
        case .refreshVisible:
          refreshVisibleCells(in: collectionView)
        case .commit(let item):
          commitItemIfNeeded(item, in: collectionView)
        case .scroll(let item):
          scrollToItem(item, animated: true, in: collectionView)
        case .applySnapshot(let plan):
          applySnapshotPlan(plan, in: collectionView)
        }
      }

      private func scrollToItem(
        _ item: ReaderViewItem,
        animated: Bool,
        in collectionView: UICollectionView
      ) {
        guard let index = session.renderedItems.firstIndex(of: item) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.layoutIfNeeded()

        if animated {
          session.beginProgrammaticScroll(to: item)
        } else {
          session.clearPendingProgrammaticCommit()
        }

        let scrollPosition: UICollectionView.ScrollPosition =
          parent.mode.isVertical ? .centeredVertically : .centeredHorizontally
        if animated {
          collectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: true)
        } else {
          guard
            let attributes = collectionView.layoutAttributesForItem(at: indexPath)
          else {
            return
          }
          let targetOffset = CGPoint(
            x: parent.mode.isVertical ? collectionView.contentOffset.x : attributes.frame.minX,
            y: parent.mode.isVertical ? attributes.frame.minY : collectionView.contentOffset.y
          )
          collectionView.setContentOffset(targetOffset, animated: false)
        }

        if !animated {
          refreshVisibleCells(in: collectionView)
        }
      }

      private func currentAnchorItem(in collectionView: UICollectionView) -> ReaderViewItem? {
        session.currentAnchor(
          fallbackCentered: centeredItem(in: collectionView),
          fallbackCurrent: parent.viewModel.currentViewItem()
        )
      }

      private func centeredItem(in collectionView: UICollectionView) -> ReaderViewItem? {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return session.committedItem }

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
          return session.committedItem
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

      private func commitPendingProgrammaticItemIfNeeded(in collectionView: UICollectionView) -> Bool {
        guard let resolvedItem = session.consumePendingProgrammaticCommit() else {
          return false
        }
        commitItemIfNeeded(resolvedItem, in: collectionView)
        return true
      }

      private func commitItemIfNeeded(_ item: ReaderViewItem, in collectionView: UICollectionView) {
        let previousCommittedItem = session.committedItem
        session.commit(item)
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
        guard session.renderedItems.indices.contains(index) else { return nil }
        return session.renderedItems[index]
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

      private func configureCell(_ cell: UICollectionViewCell, at index: Int, in collectionView: UICollectionView) {
        guard let item = renderedItem(at: index) else { return }

        if item.isEnd {
          guard let endCell = cell as? NativePagedEndCell else { return }
          let segmentBookId = item.pageID.bookId
          endCell.configure(
            previousBook: parent.viewModel.currentBook(forSegmentBookId: segmentBookId),
            nextBook: parent.viewModel.nextBook(forSegmentBookId: segmentBookId),
            readListContext: parent.readListContext,
            readingDirection: parent.readingDirection,
            readerBackground: parent.renderConfig.readerBackground,
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
          isPlaybackActive: item == session.committedItem
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
          guard let self, self.session.committedItem == item else { return }

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

        _ = session.endUserInteraction()

        session.clearPendingProgrammaticCommit()
        let committedDuringSnapshot = applyPendingSnapshotIfNeeded(in: collectionView)
        if !committedDuringSnapshot {
          commitCenteredItem(in: collectionView)
        }
      }

      func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        session.renderedItems.count
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
        collectionView.bounds.size
      }

      func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        _ = session.beginUserInteraction()
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
        _ = session.endProgrammaticScroll()
        let committedDuringSnapshot = applyPendingSnapshotIfNeeded(in: collectionView)
        if !commitPendingProgrammaticItemIfNeeded(in: collectionView) {
          if !committedDuringSnapshot {
            commitCenteredItem(in: collectionView)
          }
        }
      }
    }
  }
#endif
