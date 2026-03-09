#if os(macOS)
  import AppKit
  import SwiftUI

  struct ScrollPageView: NSViewRepresentable {
    let mode: PageViewMode
    let viewportSize: CGSize
    let readingDirection: ReadingDirection
    let splitWidePageMode: SplitWidePageMode
    let renderConfig: ReaderRenderConfig
    @Bindable var viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
      let layout = NSCollectionViewFlowLayout()
      layout.scrollDirection = mode.isVertical ? .vertical : .horizontal
      layout.minimumLineSpacing = 0
      layout.minimumInteritemSpacing = 0

      let collectionView = NativePagedLayoutAwareCollectionView()
      collectionView.collectionViewLayout = layout
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColors = [NSColor(renderConfig.readerBackground.color)]
      collectionView.isSelectable = false
      collectionView.userInterfaceLayoutDirection = .leftToRight
      collectionView.register(
        NativePagedPageCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier(Coordinator.pageCellReuseIdentifier)
      )
      collectionView.register(
        NativePagedEndCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier(Coordinator.endCellReuseIdentifier)
      )

      let scrollView = NSScrollView()
      scrollView.documentView = collectionView
      scrollView.hasVerticalScroller = false
      scrollView.hasHorizontalScroller = false
      scrollView.backgroundColor = NSColor(renderConfig.readerBackground.color)
      scrollView.drawsBackground = true
      scrollView.contentView.postsBoundsChangedNotifications = true

      context.coordinator.scrollView = scrollView
      context.coordinator.collectionView = collectionView
      context.coordinator.installObservers()
      collectionView.onDidLayout = { [weak coordinator = context.coordinator] in
        coordinator?.handleCollectionViewLayout()
      }

      return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
      guard let collectionView = scrollView.documentView as? NSCollectionView else { return }

      collectionView.backgroundColors = [NSColor(renderConfig.readerBackground.color)]
      collectionView.userInterfaceLayoutDirection = .leftToRight

      if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
        let targetDirection: NSCollectionView.ScrollDirection = mode.isVertical ? .vertical : .horizontal
        if layout.scrollDirection != targetDirection {
          layout.scrollDirection = targetDirection
          layout.invalidateLayout()
        }
      }

      context.coordinator.update(parent: self, scrollView: scrollView, collectionView: collectionView)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
      coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout,
      NativePagedPagePresentationHost
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
      weak var scrollView: NSScrollView?
      weak var collectionView: NSCollectionView?

      private let session = NativePagedReaderSession()
      private let pagePresentationCoordinator = NativePagedPagePresentationCoordinator()
      private var isAdjustingBounds = false
      private var lastViewportSize: CGSize = .zero
      private var observersInstalled = false
      private var lastRenderInputs: RenderInputs?
      private var deferredViewModelCommitTask: Task<Void, Never>?

      init(_ parent: ScrollPageView) {
        self.parent = parent
        super.init()
        pagePresentationCoordinator.host = self
      }

      func installObservers() {
        guard !observersInstalled, let scrollView else { return }
        observersInstalled = true

        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handleBoundsDidChange(_:)),
          name: NSView.boundsDidChangeNotification,
          object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(handleDidEndLiveScroll(_:)),
          name: NSScrollView.didEndLiveScrollNotification,
          object: scrollView
        )
      }

      func teardown() {
        NotificationCenter.default.removeObserver(self)
        deferredViewModelCommitTask?.cancel()
        deferredViewModelCommitTask = nil
        pagePresentationCoordinator.teardown()
        session.teardown()
      }

      func update(
        parent: ScrollPageView,
        scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) {
        self.parent = parent
        self.scrollView = scrollView
        self.collectionView = collectionView
        installObservers()
        pagePresentationCoordinator.update(viewModel: parent.viewModel)
        let displayedItems = parent.mode.displayOrderedItems(parent.viewModel.viewItems)

        let sizeChanged = updateLayoutIfNeeded(for: collectionView)
        let renderInputsChanged = updateRenderInputsIfNeeded()
        var refreshedVisibleContent = false

        if session.installInitialSnapshotIfNeeded(displayedItems) {
          collectionView.reloadData()
          collectionView.layoutSubtreeIfNeeded()
          refreshedVisibleContent = synchronizeInitialPositionIfPossible(
            in: scrollView,
            collectionView: collectionView
          )
        } else if displayedItems != session.renderedItems {
          handleViewItemsChange(displayedItems, in: scrollView, collectionView: collectionView)
          refreshedVisibleContent = true
        }

        if session.hasSyncedInitialPosition, sizeChanged, let anchor = currentAnchorItem(in: collectionView) {
          scrollToItem(anchor, animated: false, in: scrollView, collectionView: collectionView)
          refreshVisibleItems(in: collectionView)
          refreshedVisibleContent = true
        }

        if let navigationTarget = parent.viewModel.navigationTarget {
          handleNavigationChange(navigationTarget, in: scrollView, collectionView: collectionView)
        } else if renderInputsChanged && !refreshedVisibleContent {
          refreshVisibleItems(in: collectionView)
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

      private func updateLayoutIfNeeded(for collectionView: NSCollectionView) -> Bool {
        let viewportSize = resolvedViewportSize(for: collectionView)
        guard viewportSize.width > 0, viewportSize.height > 0 else { return false }

        let sizeChanged = viewportSize != lastViewportSize
        lastViewportSize = viewportSize

        if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout,
          layout.itemSize != viewportSize
        {
          layout.itemSize = viewportSize
          layout.invalidateLayout()
        }

        return sizeChanged
      }

      private func resolvedViewportSize(for collectionView: NSCollectionView) -> CGSize {
        if parent.viewportSize.width > 0, parent.viewportSize.height > 0 {
          return parent.viewportSize
        }
        return collectionView.bounds.size
      }

      private func canApplyInitialPosition(
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) -> Bool {
        let boundsSize = collectionView.bounds.size
        return scrollView.window != nil && boundsSize.width > 0 && boundsSize.height > 0
      }

      @discardableResult
      private func synchronizeInitialPositionIfPossible(
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) -> Bool {
        guard
          let currentItem = session.prepareInitialPositionIfNeeded(
            currentItem: parent.viewModel.currentViewItem()
          )
        else {
          return false
        }
        guard canApplyInitialPosition(in: scrollView, collectionView: collectionView) else { return false }

        scrollToItem(currentItem, animated: false, in: scrollView, collectionView: collectionView)
        guard let committedItem = session.completeInitialPositionIfNeeded() else { return false }
        preloadVisiblePages(for: committedItem)
        refreshVisibleItems(in: collectionView)
        scheduleViewModelCommit(for: committedItem)
        return true
      }

      func handleCollectionViewLayout() {
        guard let scrollView, let collectionView else { return }
        if synchronizeInitialPositionIfPossible(in: scrollView, collectionView: collectionView) {
          pagePresentationCoordinator.flushIfPossible()
        }
      }

      private func handleViewItemsChange(
        _ newItems: [ReaderViewItem],
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) {
        guard
          let plan = session.handleViewItemsChange(
            newItems,
            anchor: currentAnchorItem(in: collectionView)
          )
        else {
          return
        }

        applySnapshotPlan(plan, in: scrollView, collectionView: collectionView)
      }

      @discardableResult
      private func applyPendingSnapshotIfNeeded(
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) -> Bool {
        guard
          let plan = session.applyPendingSnapshotIfNeeded(
            anchorFallback: currentAnchorItem(in: collectionView)
          )
        else {
          return false
        }

        applySnapshotPlan(plan, in: scrollView, collectionView: collectionView)
        return plan.commitAnchor && plan.anchor != nil
      }

      private func applySnapshotPlan(
        _ plan: NativePagedReaderSession.SnapshotPlan,
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) {
        collectionView.reloadData()
        collectionView.layoutSubtreeIfNeeded()

        guard let anchor = plan.anchor else {
          refreshVisibleItems(in: collectionView)
          return
        }

        scrollToItem(anchor, animated: false, in: scrollView, collectionView: collectionView)
        if plan.commitAnchor {
          commitItemIfNeeded(anchor, in: collectionView)
        } else {
          refreshVisibleItems(in: collectionView)
        }
      }

      private func handleNavigationChange(
        _ navigationTarget: ReaderViewItem,
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
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
          refreshVisibleItems(in: collectionView)
        case .commit(let item):
          commitItemIfNeeded(item, in: collectionView)
        case .scroll(let item):
          scrollToItem(item, animated: true, in: scrollView, collectionView: collectionView)
        case .applySnapshot(let plan):
          applySnapshotPlan(plan, in: scrollView, collectionView: collectionView)
        }
      }

      private func scrollToItem(
        _ item: ReaderViewItem,
        animated: Bool,
        in scrollView: NSScrollView,
        collectionView: NSCollectionView
      ) {
        guard let index = session.renderedItems.firstIndex(of: item) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.layoutSubtreeIfNeeded()

        guard
          let attributes = collectionView.collectionViewLayout?.layoutAttributesForItem(at: indexPath)
        else {
          return
        }

        let targetOrigin = CGPoint(
          x: parent.mode.isVertical ? scrollView.contentView.bounds.origin.x : attributes.frame.minX,
          y: parent.mode.isVertical ? attributes.frame.minY : scrollView.contentView.bounds.origin.y
        )

        if animated {
          session.beginProgrammaticScroll(to: item)
          NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.contentView.animator().setBoundsOrigin(targetOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
          } completionHandler: {
            Task { @MainActor in
              _ = self.session.endProgrammaticScroll()
              let committedDuringSnapshot = self.applyPendingSnapshotIfNeeded(
                in: scrollView,
                collectionView: collectionView
              )
              if !self.commitPendingProgrammaticItemIfNeeded(in: collectionView) {
                if !committedDuringSnapshot {
                  self.commitCenteredItem(in: collectionView)
                }
              }
            }
          }
        } else {
          session.clearPendingProgrammaticCommit()
          isAdjustingBounds = true
          scrollView.contentView.setBoundsOrigin(targetOrigin)
          scrollView.reflectScrolledClipView(scrollView.contentView)
          isAdjustingBounds = false
          collectionView.layoutSubtreeIfNeeded()
          refreshVisibleItems(in: collectionView)
        }
      }

      private func currentAnchorItem(in collectionView: NSCollectionView) -> ReaderViewItem? {
        session.currentAnchor(
          fallbackCentered: centeredItem(in: collectionView),
          fallbackCurrent: parent.viewModel.currentViewItem()
        )
      }

      private func centeredItem(in collectionView: NSCollectionView) -> ReaderViewItem? {
        let visibleItems = collectionView.visibleItems()
        guard !visibleItems.isEmpty else { return session.committedItem }

        let visibleRect = collectionView.enclosingScrollView?.contentView.bounds ?? collectionView.visibleRect
        let center = CGPoint(x: visibleRect.midX, y: visibleRect.midY)

        let nearestItem = visibleItems.min { lhs, rhs in
          distanceFromCenter(of: lhs, to: center) < distanceFromCenter(of: rhs, to: center)
        }

        guard let nearestItem else { return session.committedItem }
        let index = nearestItem.representedObject as? Int ?? -1
        return renderedItem(at: index) ?? session.committedItem
      }

      private func distanceFromCenter(of item: NSCollectionViewItem, to center: CGPoint) -> CGFloat {
        let frame = item.view.frame
        let dx = frame.midX - center.x
        let dy = frame.midY - center.y
        return sqrt(dx * dx + dy * dy)
      }

      private func commitCenteredItem(in collectionView: NSCollectionView) {
        guard let item = centeredItem(in: collectionView) else { return }
        commitItemIfNeeded(item, in: collectionView)
      }

      private func commitPendingProgrammaticItemIfNeeded(in collectionView: NSCollectionView) -> Bool {
        guard let resolvedItem = session.consumePendingProgrammaticCommit() else {
          return false
        }
        commitItemIfNeeded(resolvedItem, in: collectionView)
        return true
      }

      private func commitItemIfNeeded(_ item: ReaderViewItem, in collectionView: NSCollectionView) {
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

      private func refreshVisibleItems(
        in collectionView: NSCollectionView,
        matching pageIDs: Set<ReaderPageID>? = nil
      ) {
        for item in collectionView.visibleItems() {
          let index = item.representedObject as? Int ?? -1
          guard let viewItem = renderedItem(at: index) else { continue }
          if let pageIDs, !viewItem.pageIDs.contains(where: pageIDs.contains) {
            continue
          }
          configureItem(item, at: index, in: collectionView)
        }
      }

      func hasVisiblePagePresentationContent() -> Bool {
        guard let collectionView else { return false }
        return !collectionView.visibleItems().isEmpty
      }

      func applyPagePresentationInvalidation(_ invalidation: ReaderPagePresentationInvalidation) {
        guard let collectionView else { return }

        switch invalidation {
        case .all:
          refreshVisibleItems(in: collectionView)
        case .pages(let pageIDs):
          refreshVisibleItems(in: collectionView, matching: pageIDs)
        }
      }

      private func renderedItem(at index: Int) -> ReaderViewItem? {
        guard session.renderedItems.indices.contains(index) else { return nil }
        return session.renderedItems[index]
      }

      private func fallbackItem(
        for indexPath: IndexPath,
        in collectionView: NSCollectionView
      ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
          withIdentifier: NSUserInterfaceItemIdentifier(Self.pageCellReuseIdentifier),
          for: indexPath
        )
        if let pageCell = item as? NativePagedPageCell {
          pageCell.resetContent(backgroundColor: NSColor(parent.renderConfig.readerBackground.color))
        }
        return item
      }

      private func configureItem(_ item: NSCollectionViewItem, at index: Int, in collectionView: NSCollectionView) {
        guard let viewItem = renderedItem(at: index) else { return }
        item.representedObject = index

        if viewItem.isEnd {
          guard let endItem = item as? NativePagedEndCell else { return }
          let segmentBookId = viewItem.pageID.bookId
          endItem.configure(
            previousBook: parent.viewModel.currentBook(forSegmentBookId: segmentBookId),
            nextBook: parent.viewModel.nextBook(forSegmentBookId: segmentBookId),
            readListContext: parent.readListContext,
            readingDirection: parent.readingDirection,
            renderConfig: parent.renderConfig,
            onDismiss: parent.onDismiss
          )
          return
        }

        guard let pageItem = item as? NativePagedPageCell else { return }
        pageItem.view.layer?.backgroundColor = NSColor(parent.renderConfig.readerBackground.color).cgColor
        pageItem.configure(
          viewModel: parent.viewModel,
          item: viewItem,
          screenSize: resolvedViewportSize(for: collectionView),
          renderConfig: parent.renderConfig,
          readingDirection: parent.readingDirection,
          splitWidePageMode: parent.splitWidePageMode,
          isPlaybackActive: viewItem == session.committedItem
        )
      }

      private func refreshCommittedPlaybackState(
        from previousItem: ReaderViewItem?,
        to currentItem: ReaderViewItem,
        in collectionView: NSCollectionView
      ) {
        guard previousItem != currentItem else { return }

        for item in collectionView.visibleItems() {
          let index = item.representedObject as? Int ?? -1
          guard let viewItem = renderedItem(at: index),
            let pageItem = item as? NativePagedPageCell
          else {
            continue
          }

          guard viewItem == previousItem || viewItem == currentItem else { continue }
          pageItem.updatePlaybackActive(viewItem == currentItem)
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

      @objc private func handleBoundsDidChange(_ notification: Notification) {
        guard !isAdjustingBounds, !session.isProgrammaticScrolling else { return }
        _ = session.beginUserInteraction()
      }

      @objc private func handleDidEndLiveScroll(_ notification: Notification) {
        guard let scrollView, let collectionView else { return }

        _ = session.endUserInteraction()

        session.clearPendingProgrammaticCommit()
        let committedDuringSnapshot = applyPendingSnapshotIfNeeded(
          in: scrollView,
          collectionView: collectionView
        )
        if !committedDuringSnapshot {
          commitCenteredItem(in: collectionView)
        }
      }

      func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
      }

      func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        session.renderedItems.count
      }

      func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
      ) -> NSCollectionViewItem {
        guard let renderedItem = renderedItem(at: indexPath.item) else {
          return fallbackItem(for: indexPath, in: collectionView)
        }
        let identifier = NSUserInterfaceItemIdentifier(
          renderedItem.isEnd
            ? Self.endCellReuseIdentifier : Self.pageCellReuseIdentifier
        )
        let item = collectionView.makeItem(withIdentifier: identifier, for: indexPath)
        configureItem(item, at: indexPath.item, in: collectionView)
        return item
      }

      func collectionView(
        _ collectionView: NSCollectionView,
        willDisplay item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath
      ) {
        pagePresentationCoordinator.flushIfPossible()
      }

      func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> CGSize {
        collectionView.bounds.size
      }
    }
  }
#endif
