//
// WebtoonReaderView_iOS.swift
//
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct WebtoonReaderView: UIViewRepresentable {
    let viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void
    let onCenterTap: (() -> Void)?
    let onZoomRequest: ((ReaderPageID, CGPoint) -> Void)?
    let pageWidth: CGFloat
    let renderConfig: ReaderRenderConfig

    init(
      viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      renderConfig: ReaderRenderConfig,
      readListContext: ReaderReadListContext? = nil,
      onDismiss: @escaping () -> Void = {},
      onCenterTap: (() -> Void)? = nil,
      onZoomRequest: ((ReaderPageID, CGPoint) -> Void)? = nil
    ) {
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.renderConfig = renderConfig
      self.readListContext = readListContext
      self.onDismiss = onDismiss
      self.onCenterTap = onCenterTap
      self.onZoomRequest = onZoomRequest
    }

    func makeUIView(context: Context) -> UICollectionView {
      let layout = WebtoonLayout()
      let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      collectionView.showsVerticalScrollIndicator = false
      collectionView.showsHorizontalScrollIndicator = false
      collectionView.contentInsetAdjustmentBehavior = .never
      collectionView.bounces = false
      collectionView.scrollsToTop = false
      collectionView.isPrefetchingEnabled = false

      collectionView.register(WebtoonPageCell.self, forCellWithReuseIdentifier: "WebtoonPageCell")
      collectionView.register(
        WebtoonFooterCell.self, forCellWithReuseIdentifier: "WebtoonFooterCell")

      let tapGesture = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleTap(_:))
      )
      tapGesture.numberOfTapsRequired = 1
      tapGesture.cancelsTouchesInView = false
      tapGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(tapGesture)

      let doubleTapGesture = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleDoubleTap(_:))
      )
      doubleTapGesture.numberOfTapsRequired = 2
      doubleTapGesture.cancelsTouchesInView = false
      doubleTapGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(doubleTapGesture)

      let longPressGesture = UILongPressGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleLongPress(_:))
      )
      longPressGesture.minimumPressDuration = WebtoonConstants.longPressMinimumDuration
      longPressGesture.cancelsTouchesInView = false
      longPressGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(longPressGesture)

      let pinchGesture = UIPinchGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handlePinch(_:))
      )
      pinchGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(pinchGesture)

      context.coordinator.collectionView = collectionView
      context.coordinator.scheduleInitialScroll()

      return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
      collectionView.backgroundColor = UIColor(renderConfig.readerBackground.color)
      context.coordinator.update(
        viewModel: viewModel,
        readListContext: readListContext,
        onDismiss: onDismiss,
        onCenterTap: onCenterTap,
        onZoomRequest: onZoomRequest,
        pageWidth: pageWidth,
        collectionView: collectionView,
        renderConfig: renderConfig
      )
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource,
      UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate
    {
      var collectionView: UICollectionView?
      private var scrollEngine: WebtoonScrollEngine
      weak var viewModel: ReaderViewModel?
      var readListContext: ReaderReadListContext?
      var onDismiss: (() -> Void)?
      var onCenterTap: (() -> Void)?
      var onZoomRequest: ((ReaderPageID, CGPoint) -> Void)?
      var lastPagesCount: Int = 0
      var isUserScrolling: Bool = false
      var isProgrammaticAnimatedScroll: Bool = false
      var pageWidth: CGFloat = 0
      var readerBackground: ReaderBackground = .system
      var tapZoneMode: TapZoneMode = .auto
      var tapZoneSize: TapZoneSize = .large
      var doubleTapZoomMode: DoubleTapZoomMode = .fast
      var showPageNumber: Bool = true
      var isLongPress: Bool = false
      var hasTriggeredZoomGesture: Bool = false
      private var singleTapWorkItem: DispatchWorkItem?

      var heightCache = WebtoonPageHeightCache()

      init(_ parent: WebtoonReaderView) {
        self.scrollEngine = WebtoonScrollEngine(
          initialPageID: parent.viewModel.currentReaderPage?.id
        )
        self.viewModel = parent.viewModel
        self.readListContext = parent.readListContext
        self.onDismiss = parent.onDismiss
        self.onCenterTap = parent.onCenterTap
        self.onZoomRequest = parent.onZoomRequest
        self.lastPagesCount = parent.viewModel.pageCount
        self.pageWidth = parent.pageWidth
        self.heightCache.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.renderConfig.readerBackground
        self.tapZoneMode = parent.renderConfig.tapZoneMode
        self.tapZoneSize = parent.renderConfig.tapZoneSize
        self.doubleTapZoomMode = parent.renderConfig.doubleTapZoomMode
        self.showPageNumber = parent.renderConfig.showPageNumber
        super.init()
        _ = scrollEngine.rebuildContentItemsIfNeeded(viewModel: viewModel)
      }

      // MARK: - Helper Methods

      private var pageCount: Int {
        viewModel?.pageCount ?? 0
      }

      private func itemIndex(forPageID pageID: ReaderPageID?) -> Int? {
        scrollEngine.itemIndex(forPageID: pageID)
      }

      private func indexPath(forPageID pageID: ReaderPageID?) -> IndexPath? {
        guard let itemIndex = itemIndex(forPageID: pageID) else { return nil }
        return IndexPath(item: itemIndex, section: 0)
      }

      func scheduleInitialScroll() {
        scrollEngine.scheduleInitialScroll(
          currentPageID: scrollEngine.currentPageID,
          schedule: scheduleOnMain,
          canScrollToPageID: { [weak self] pageID in
            guard let self else { return false }
            guard self.pageCount > 0 else { return false }
            return self.itemIndex(forPageID: pageID) != nil
          },
          perform: { [weak self] pageID in self?.scrollToInitialPage(pageID) }
        )
      }

      func requestInitialScroll(_ pageID: ReaderPageID?, delay: TimeInterval) {
        scrollEngine.requestInitialScroll(
          pageID,
          delay: delay,
          schedule: scheduleOnMain,
          canScrollToPageID: { [weak self] targetPageID in
            guard let self else { return false }
            guard self.pageCount > 0 else { return false }
            return self.itemIndex(forPageID: targetPageID) != nil
          },
          perform: { [weak self] targetPageID in self?.scrollToInitialPage(targetPageID) }
        )
      }

      func update(
        viewModel: ReaderViewModel,
        readListContext: ReaderReadListContext?,
        onDismiss: @escaping () -> Void,
        onCenterTap: (() -> Void)?,
        onZoomRequest: ((ReaderPageID, CGPoint) -> Void)?,
        pageWidth: CGFloat,
        collectionView: UICollectionView,
        renderConfig: ReaderRenderConfig
      ) {
        applySafeAreaInsetsIfNeeded(for: collectionView)
        self.viewModel = viewModel
        self.readListContext = readListContext
        self.onDismiss = onDismiss
        self.onCenterTap = onCenterTap
        self.onZoomRequest = onZoomRequest
        self.pageWidth = pageWidth
        self.readerBackground = renderConfig.readerBackground
        self.tapZoneMode = renderConfig.tapZoneMode
        self.tapZoneSize = renderConfig.tapZoneSize
        self.doubleTapZoomMode = renderConfig.doubleTapZoomMode
        self.showPageNumber = renderConfig.showPageNumber

        let currentPageID = viewModel.currentReaderPage?.id
        scrollEngine.currentPageID = currentPageID
        let pageCount = viewModel.pageCount
        let didContentItemsChange = scrollEngine.rebuildContentItemsIfNeeded(viewModel: viewModel)

        if lastPagesCount != pageCount
          || didContentItemsChange
          || abs(heightCache.lastPageWidth - pageWidth) > 0.1
        {
          if isProgrammaticAnimatedScroll {
            scrollEngine.pendingReloadCurrentPageID = currentPageID
          } else {
            handleDataReload(collectionView: collectionView, currentPageID: currentPageID)
          }
        }

        for cell in collectionView.visibleCells {
          if let pageCell = cell as? WebtoonPageCell {
            pageCell.readerBackground = renderConfig.readerBackground
            pageCell.showPageNumber = renderConfig.showPageNumber
          } else if let footerCell = cell as? WebtoonFooterCell,
            let indexPath = collectionView.indexPath(for: footerCell),
            indexPath.item < scrollEngine.contentItems.count,
            case .end(let segmentBookId) = scrollEngine.contentItems[indexPath.item]
          {
            footerCell.readerBackground = renderConfig.readerBackground
            footerCell.configure(
              previousBook: viewModel.currentBook(forSegmentBookId: segmentBookId),
              nextBook: viewModel.nextBook(forSegmentBookId: segmentBookId),
              readListContext: readListContext,
              onDismiss: onDismiss
            )
          }
        }

        if !scrollEngine.hasScrolledToInitialPage, scrollEngine.itemCount > 0, currentPageID != nil {
          scrollToInitialPage(currentPageID)
        }

        if let targetPageID = viewModel.navigationTarget?.pageID,
          itemIndex(forPageID: targetPageID) != nil
        {
          scrollToPage(targetPageID, animated: true)
          viewModel.clearNavigationTarget()
          if self.scrollEngine.currentPageID != targetPageID {
            self.scrollEngine.currentPageID = targetPageID
            viewModel.updateCurrentPosition(pageID: targetPageID)
          }
        } else {
          if self.scrollEngine.currentPageID != currentPageID {
            self.scrollEngine.currentPageID = currentPageID
          }
        }
      }

      private func applySafeAreaInsetsIfNeeded(for collectionView: UICollectionView) {
        guard collectionView.traitCollection.userInterfaceIdiom == .phone else {
          if collectionView.contentInset != .zero {
            collectionView.contentInset = .zero
            collectionView.scrollIndicatorInsets = .zero
          }
          return
        }

        let safeInsets = collectionView.safeAreaInsets
        let newInsets = UIEdgeInsets(
          top: safeInsets.top, left: 0, bottom: safeInsets.bottom, right: 0)

        if collectionView.contentInset != newInsets {
          collectionView.contentInset = newInsets
          collectionView.scrollIndicatorInsets = newInsets
        }
      }

      private func handleDataReload(collectionView: UICollectionView, currentPageID: ReaderPageID?) {
        let pageCount = self.pageCount
        let pagesChanged = lastPagesCount != pageCount
        let offsetWithinCurrentPage =
          scrollEngine.hasScrolledToInitialPage
          ? captureOffsetWithinPage(currentPageID, in: collectionView) : nil

        if pagesChanged {
          heightCache.reset()
        }

        lastPagesCount = pageCount
        heightCache.rescaleIfNeeded(newWidth: pageWidth)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if let offsetWithinCurrentPage,
          let currentPageID,
          restoreOffsetWithinPage(
            offsetWithinCurrentPage,
            for: currentPageID,
            in: collectionView
          )
        {
          scrollEngine.hasScrolledToInitialPage = true
          return
        }

        scrollEngine.hasScrolledToInitialPage = false
        scrollEngine.resetInitialScrollRetrier()
        if currentPageID != nil {
          requestInitialScroll(currentPageID, delay: WebtoonConstants.layoutReadyDelay)
        }
      }

      private func captureOffsetWithinPage(_ pageID: ReaderPageID?, in collectionView: UICollectionView) -> CGFloat? {
        guard let pageID else { return nil }
        let currentTopY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        return WebtoonScrollOffset.captureOffsetWithinPage(
          pageID: pageID,
          currentTopY: currentTopY,
          itemIndexForPage: { [weak self] pageID in
            self?.itemIndex(forPageID: pageID)
          },
          frameForItemIndex: { itemIndex in
            collectionView.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
          }
        )
      }

      @discardableResult
      private func restoreOffsetWithinPage(
        _ offsetWithinPage: CGFloat,
        for pageID: ReaderPageID,
        in collectionView: UICollectionView
      ) -> Bool {
        guard
          let targetTopY = WebtoonScrollOffset.targetTopYForPage(
            pageID: pageID,
            offsetWithinPage: offsetWithinPage,
            itemIndexForPage: { [weak self] pageID in
              self?.itemIndex(forPageID: pageID)
            },
            frameForItemIndex: { itemIndex in
              collectionView.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
            }
          )
        else {
          return false
        }
        let targetOffset = targetTopY - collectionView.adjustedContentInset.top
        let minOffset = -collectionView.adjustedContentInset.top
        let maxOffset = max(
          collectionView.contentSize.height - collectionView.bounds.height
            + collectionView.adjustedContentInset.bottom,
          minOffset
        )
        let clampedOffset = WebtoonScrollOffset.clampedY(
          targetOffset,
          min: minOffset,
          max: maxOffset
        )
        collectionView.setContentOffset(
          CGPoint(x: collectionView.contentOffset.x, y: clampedOffset),
          animated: false
        )
        return true
      }

      private func applyPendingReloadIfNeeded() {
        guard let pendingPageID = scrollEngine.pendingReloadCurrentPageID else { return }
        guard let collectionView = collectionView else { return }
        scrollEngine.pendingReloadCurrentPageID = nil

        let currentPageID = viewModel?.currentReaderPage?.id ?? pendingPageID
        handleDataReload(collectionView: collectionView, currentPageID: currentPageID)
      }

      func scrollToPage(_ pageID: ReaderPageID, animated: Bool) {
        guard let collectionView = collectionView else { return }
        guard let itemIndex = itemIndex(forPageID: pageID) else { return }

        let indexPath = IndexPath(item: itemIndex, section: 0)

        if collectionView.contentSize.height > 0 {
          isProgrammaticAnimatedScroll = animated
          collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        } else {
          requestScrollToPage(
            pageID, animated: animated, delay: WebtoonConstants.layoutReadyDelay)
        }
      }

      func requestScrollToPage(_ pageID: ReaderPageID, animated: Bool, delay: TimeInterval) {
        scheduleOnMain(after: delay) { [weak self] in
          guard let self = self,
            let collectionView = self.collectionView
          else { return }
          guard let itemIndex = self.scrollEngine.itemIndex(forPageID: pageID) else { return }
          self.isProgrammaticAnimatedScroll = animated
          collectionView.scrollToItem(
            at: IndexPath(item: itemIndex, section: 0),
            at: .top,
            animated: animated
          )
        }
      }

      func scrollToInitialPage(_ pageID: ReaderPageID?) {
        guard !scrollEngine.hasScrolledToInitialPage else { return }
        guard let collectionView = collectionView,
          let itemIndex = itemIndex(forPageID: pageID),
          collectionView.bounds.width > 0 && collectionView.bounds.height > 0
        else {
          if !scrollEngine.hasScrolledToInitialPage {
            requestInitialScroll(pageID, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }

        collectionView.layoutIfNeeded()

        guard collectionView.contentSize.height > 0 else {
          if !scrollEngine.hasScrolledToInitialPage {
            requestInitialScroll(pageID, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }

        let indexPath = IndexPath(item: itemIndex, section: 0)
        scrollEngine.hasScrolledToInitialPage = true
        collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
        collectionView.layoutIfNeeded()
      }

      // MARK: - UICollectionViewDataSource

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
        -> Int
      {
        scrollEngine.itemCount
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
      {
        guard indexPath.item < scrollEngine.contentItems.count else {
          return UICollectionViewCell()
        }

        switch scrollEngine.contentItems[indexPath.item] {
        case .end(let segmentBookId):
          let item = collectionView.dequeueReusableCell(
            withReuseIdentifier: "WebtoonFooterCell",
            for: indexPath
          )
          guard let cell = item as? WebtoonFooterCell else {
            assertionFailure("Failed to dequeue WebtoonFooterCell")
            return item
          }
          cell.readerBackground = readerBackground
          cell.configure(
            previousBook: viewModel?.currentBook(forSegmentBookId: segmentBookId),
            nextBook: viewModel?.nextBook(forSegmentBookId: segmentBookId),
            readListContext: readListContext,
            onDismiss: onDismiss
          )
          return cell
        case .page(let pageID):
          let item = collectionView.dequeueReusableCell(
            withReuseIdentifier: "WebtoonPageCell",
            for: indexPath
          )
          guard let cell = item as? WebtoonPageCell else {
            assertionFailure("Failed to dequeue WebtoonPageCell")
            return item
          }
          cell.readerBackground = readerBackground

          let preloadedImage = viewModel?.preloadedImage(for: pageID)
          let pageLabel =
            viewModel?.displayPageNumber(for: pageID).map(String.init)
            ?? String(pageID.pageNumber)

          if preloadedImage == nil {
            Task { @MainActor [weak self] in
              guard let self = self else { return }
              await self.loadImage(for: pageID)
            }
          }

          cell.configure(
            pageLabel: pageLabel,
            image: preloadedImage,
            showPageNumber: showPageNumber
          )

          return cell
        }
      }

      // MARK: - UICollectionViewDelegateFlowLayout

      func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> CGSize {
        guard indexPath.item < scrollEngine.contentItems.count else {
          return CGSize(width: pageWidth, height: 0)
        }

        switch scrollEngine.contentItems[indexPath.item] {
        case .end:
          return CGSize(width: pageWidth, height: WebtoonConstants.footerHeight)
        case .page(let pageID):
          guard let page = viewModel?.page(for: pageID) else {
            return CGSize(width: pageWidth, height: pageWidth * 3)
          }
          let height = heightCache.height(for: pageID, page: page, pageWidth: pageWidth)
          let scale = collectionView.traitCollection.displayScale
          let alignedHeight = scale > 0 ? ceil(height * scale) / scale : height
          return CGSize(width: pageWidth, height: alignedHeight)
        }
      }

      // MARK: - UICollectionViewDelegate

      func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
        isProgrammaticAnimatedScroll = false
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isUserScrolling {
          updateCurrentPage()
        }
      }

      func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finalizeScrollInteraction()
      }

      func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
          finalizeScrollInteraction()
        }
      }

      func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isProgrammaticAnimatedScroll = false
        finalizeScrollInteraction()
      }

      private func finalizeScrollInteraction() {
        isUserScrolling = false
        updateCurrentPage()
        applyPendingReloadIfNeeded()
        updateCurrentPage()
        viewModel?.cleanupDistantImagesAroundCurrentPage()
      }

      private func updateCurrentPage() {
        guard let collectionView = collectionView else { return }
        let totalItems = scrollEngine.itemCount
        guard totalItems > 0 else { return }

        let scrollOffset = collectionView.contentOffset.y
        let scrollViewHeight = collectionView.bounds.height
        let viewportBottom = scrollOffset + scrollViewHeight
        let visibleItemIndices = collectionView.indexPathsForVisibleItems.map(\.item)

        let newCurrentItemIndex = WebtoonContentItems.lastVisibleItemIndex(
          itemCount: totalItems,
          viewportBottom: viewportBottom,
          threshold: WebtoonConstants.bottomThreshold,
          visibleItemIndices: visibleItemIndices
        ) { itemIndex in
          collectionView.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
        }

        guard
          let resolvedPageID = scrollEngine.resolvedPageID(
            forItemIndex: newCurrentItemIndex,
            viewModel: viewModel
          )
        else {
          return
        }

        if scrollEngine.currentPageID != resolvedPageID {
          scrollEngine.currentPageID = resolvedPageID
          viewModel?.updateCurrentPosition(pageID: resolvedPageID)
        }
      }

      // MARK: - Image Loading

      @MainActor
      func loadImage(for pageID: ReaderPageID) async {
        guard let viewModel = viewModel else {
          return
        }

        if let preloadedImage = viewModel.preloadedImage(for: pageID) {
          pageCell(for: pageID)?.setImage(preloadedImage)
          return
        }

        if let image = await viewModel.preloadImage(for: pageID) {
          pageCell(for: pageID)?.setImage(image)
        } else {
          showImageError(for: pageID)
        }
      }

      private func pageCell(for pageID: ReaderPageID) -> WebtoonPageCell? {
        guard let collectionView else { return nil }
        guard let indexPath = indexPath(forPageID: pageID) else { return nil }
        return collectionView.cellForItem(at: indexPath) as? WebtoonPageCell
      }

      private func showImageError(for pageID: ReaderPageID) {
        pageCell(for: pageID)?.showError()
      }

      // MARK: - Tap Gesture Handling

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPress = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + WebtoonConstants.longPressReleaseDelay) {
            [weak self] in
            self?.isLongPress = false
          }
        }
      }

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        singleTapWorkItem?.cancel()

        guard !isLongPress else { return }

        guard let collectionView = collectionView,
          let view = collectionView.superview
        else { return }

        if collectionView.isDragging || collectionView.isDecelerating {
          return
        }

        let location = gesture.location(in: view)
        let screenHeight = view.bounds.height
        let screenWidth = view.bounds.width

        let normalizedX = location.x / screenWidth
        let normalizedY = location.y / screenHeight

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: tapZoneMode,
          readingDirection: .webtoon,
          zoneThreshold: tapZoneSize.value
        )

        let workItem = DispatchWorkItem { [weak self] in
          guard let self = self else { return }
          switch action {
          case .previous:
            self.scrollUp(collectionView: collectionView, screenHeight: screenHeight)
          case .next:
            self.scrollDown(collectionView: collectionView, screenHeight: screenHeight)
          case .toggleControls:
            self.onCenterTap?()
          }
        }
        singleTapWorkItem = workItem

        let delay = doubleTapZoomMode.tapDebounceDelay
        if delay <= 0 {
          workItem.perform()
        } else {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
      }

      @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard !isLongPress else { return }
        guard let collectionView = collectionView else { return }
        if collectionView.isDragging || collectionView.isDecelerating { return }
        if doubleTapZoomMode == .disabled { return }

        singleTapWorkItem?.cancel()
        singleTapWorkItem = nil

        let location = gesture.location(in: collectionView)
        requestZoom(at: location)
      }

      @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let collectionView = collectionView else { return }

        switch gesture.state {
        case .began:
          hasTriggeredZoomGesture = false
        case .changed:
          if hasTriggeredZoomGesture { return }
          let delta = gesture.scale - 1.0
          guard delta > 0.05 else { return }
          hasTriggeredZoomGesture = true
          let location = gesture.location(in: collectionView)
          requestZoom(at: location)
        case .ended, .cancelled, .failed:
          hasTriggeredZoomGesture = false
        default:
          break
        }
      }

      // MARK: - UIGestureRecognizerDelegate

      func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
        -> Bool
      {
        var touchedView: UIView? = touch.view
        while let currentView = touchedView {
          if currentView is UIControl {
            return false
          }
          touchedView = currentView.superview
        }
        return true
      }

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        // Always allow simultaneous recognition to ensure scrolling and context menus work.
        return true
      }

      private func requestZoom(at location: CGPoint) {
        guard let result = pageIndexAndAnchor(for: location) else { return }
        onZoomRequest?(result.pageID, result.anchor)
      }

      private func pageIndexAndAnchor(for location: CGPoint) -> (pageID: ReaderPageID, anchor: CGPoint)? {
        guard let collectionView = collectionView else { return nil }

        if let indexPath = collectionView.indexPathForItem(at: location),
          let pageID = scrollEngine.resolvedPageID(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          )
        {
          if let cell = collectionView.cellForItem(at: indexPath) {
            let local = cell.contentView.convert(location, from: collectionView)
            return (pageID, normalizedAnchor(in: cell.contentView.bounds, location: local))
          }
          if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
            return (pageID, normalizedAnchor(in: attributes.frame, location: location))
          }
        }

        guard let fallbackPageID = scrollEngine.currentPageID else { return nil }
        guard let fallbackIndexPath = indexPath(forPageID: fallbackPageID) else { return nil }
        if let cell = collectionView.cellForItem(at: fallbackIndexPath) {
          let local = cell.contentView.convert(location, from: collectionView)
          return (fallbackPageID, normalizedAnchor(in: cell.contentView.bounds, location: local))
        }
        if let attributes = collectionView.layoutAttributesForItem(at: fallbackIndexPath) {
          return (fallbackPageID, normalizedAnchor(in: attributes.frame, location: location))
        }
        return nil
      }

      private func normalizedAnchor(in frame: CGRect, location: CGPoint) -> CGPoint {
        guard frame.width > 0, frame.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let localX = location.x - frame.minX
        let localY = location.y - frame.minY
        let x = min(max(localX / frame.width, 0), 1)
        let y = min(max(localY / frame.height, 0), 1)
        return CGPoint(x: x, y: y)
      }

      private func scrollUp(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetOffset = max(currentOffset - scrollAmount, 0)
        scrollToOffsetIfNeeded(targetOffset, in: collectionView)
      }

      private func scrollDown(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let maxOffset = max(collectionView.contentSize.height - screenHeight, 0)
        let targetOffset = min(
          currentOffset + scrollAmount,
          maxOffset
        )
        scrollToOffsetIfNeeded(targetOffset, in: collectionView)
      }

      private func scrollToOffsetIfNeeded(_ targetOffset: CGFloat, in collectionView: UICollectionView) {
        let currentOffset = collectionView.contentOffset.y
        guard abs(targetOffset - currentOffset) > WebtoonConstants.offsetEpsilon else {
          isProgrammaticAnimatedScroll = false
          return
        }
        preheatPages(at: targetOffset, in: collectionView)
        collectionView.layoutIfNeeded()
        isProgrammaticAnimatedScroll = true
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }

      private func preheatPages(at targetOffset: CGFloat, in collectionView: UICollectionView) {
        let centerY = targetOffset + collectionView.bounds.height / 2
        let centerPoint = CGPoint(x: collectionView.bounds.width / 2, y: centerY)
        guard let indexPath = collectionView.indexPathForItem(at: centerPoint),
          let targetPageID = scrollEngine.resolvedPageID(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          ),
          let pageIDs = viewModel?.neighboringPageIDs(
            around: targetPageID,
            radius: WebtoonConstants.preheatRadius
          ),
          !pageIDs.isEmpty
        else { return }
        Task { @MainActor [weak self] in
          for pageID in pageIDs {
            await self?.loadImage(for: pageID)
          }
        }
      }
    }
  }
#endif
