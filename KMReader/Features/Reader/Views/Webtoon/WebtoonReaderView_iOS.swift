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
    let onPageChange: ((Int) -> Void)?
    let onCenterTap: (() -> Void)?
    let onZoomRequest: ((Int, CGPoint) -> Void)?
    let pageWidth: CGFloat
    let renderConfig: ReaderRenderConfig

    init(
      viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      renderConfig: ReaderRenderConfig,
      readListContext: ReaderReadListContext? = nil,
      onDismiss: @escaping () -> Void = {},
      onPageChange: ((Int) -> Void)? = nil,
      onCenterTap: (() -> Void)? = nil,
      onZoomRequest: ((Int, CGPoint) -> Void)? = nil
    ) {
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.renderConfig = renderConfig
      self.readListContext = readListContext
      self.onDismiss = onDismiss
      self.onPageChange = onPageChange
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
        onPageChange: onPageChange,
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
      var onPageChange: ((Int) -> Void)?
      var onCenterTap: (() -> Void)?
      var onZoomRequest: ((Int, CGPoint) -> Void)?
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
          initialPage: parent.viewModel.currentPageIndex,
          initialPageID: parent.viewModel.currentReaderPage?.id
        )
        self.viewModel = parent.viewModel
        self.readListContext = parent.readListContext
        self.onDismiss = parent.onDismiss
        self.onPageChange = parent.onPageChange
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

      func isValidPageIndex(_ index: Int) -> Bool {
        index >= 0 && index < pageCount
      }

      private func pageIndex(forPageID pageID: ReaderPageID?) -> Int? {
        guard let index = scrollEngine.pageIndex(forPageID: pageID, viewModel: viewModel) else {
          return nil
        }
        return isValidPageIndex(index) ? index : nil
      }

      private func itemIndex(forPageIndex pageIndex: Int) -> Int? {
        guard let pageID = scrollEngine.pageID(forPageIndex: pageIndex, viewModel: viewModel) else {
          return nil
        }
        return scrollEngine.itemIndex(forPageID: pageID)
      }

      private func indexPath(forPageIndex pageIndex: Int) -> IndexPath? {
        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return nil }
        return IndexPath(item: itemIndex, section: 0)
      }

      func scheduleInitialScroll() {
        scrollEngine.scheduleInitialScroll(
          currentPageID: scrollEngine.currentPageID,
          schedule: scheduleOnMain,
          canScrollToPageID: { [weak self] pageID in
            guard let self else { return false }
            guard self.pageCount > 0 else { return false }
            return self.pageIndex(forPageID: pageID) != nil
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
            return self.pageIndex(forPageID: targetPageID) != nil
          },
          perform: { [weak self] targetPageID in self?.scrollToInitialPage(targetPageID) }
        )
      }

      func update(
        viewModel: ReaderViewModel,
        readListContext: ReaderReadListContext?,
        onDismiss: @escaping () -> Void,
        onPageChange: ((Int) -> Void)?,
        onCenterTap: (() -> Void)?,
        onZoomRequest: ((Int, CGPoint) -> Void)?,
        pageWidth: CGFloat,
        collectionView: UICollectionView,
        renderConfig: ReaderRenderConfig
      ) {
        applySafeAreaInsetsIfNeeded(for: collectionView)
        self.viewModel = viewModel
        self.readListContext = readListContext
        self.onDismiss = onDismiss
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onZoomRequest = onZoomRequest
        self.pageWidth = pageWidth
        self.readerBackground = renderConfig.readerBackground
        self.tapZoneMode = renderConfig.tapZoneMode
        self.tapZoneSize = renderConfig.tapZoneSize
        self.doubleTapZoomMode = renderConfig.doubleTapZoomMode
        self.showPageNumber = renderConfig.showPageNumber

        let currentPage = viewModel.currentPageIndex
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

        if let targetPageIndex = viewModel.targetPageIndex,
          isValidPageIndex(targetPageIndex)
        {
          scrollToPage(targetPageIndex, animated: true)
          viewModel.targetPageIndex = nil
          if self.scrollEngine.currentPage != targetPageIndex {
            self.scrollEngine.currentPage = targetPageIndex
            self.scrollEngine.currentPageID = scrollEngine.pageID(
              forPageIndex: targetPageIndex,
              viewModel: viewModel
            )
            onPageChange?(targetPageIndex)
          }
        } else {
          if self.scrollEngine.currentPage != currentPage, isValidPageIndex(currentPage) {
            self.scrollEngine.currentPage = currentPage
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
        let currentPageIndex = pageIndex(forPageID: currentPageID)
        let offsetWithinCurrentPage =
          scrollEngine.hasScrolledToInitialPage && currentPageIndex != nil
          ? captureOffsetWithinPage(currentPageIndex ?? 0, in: collectionView) : nil

        if pagesChanged {
          heightCache.reset()
        }

        lastPagesCount = pageCount
        heightCache.rescaleIfNeeded(newWidth: pageWidth)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if let offsetWithinCurrentPage,
          let currentPageIndex,
          restoreOffsetWithinPage(
            offsetWithinCurrentPage,
            for: currentPageIndex,
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

      private func captureOffsetWithinPage(_ pageIndex: Int, in collectionView: UICollectionView) -> CGFloat? {
        let currentTopY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        return WebtoonScrollOffset.captureOffsetWithinPage(
          pageIndex: pageIndex,
          currentTopY: currentTopY,
          isValidPage: isValidPageIndex,
          itemIndexForPage: itemIndex(forPageIndex:),
          frameForItemIndex: { itemIndex in
            collectionView.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
          }
        )
      }

      @discardableResult
      private func restoreOffsetWithinPage(
        _ offsetWithinPage: CGFloat,
        for pageIndex: Int,
        in collectionView: UICollectionView
      ) -> Bool {
        guard
          let targetTopY = WebtoonScrollOffset.targetTopYForPage(
            pageIndex: pageIndex,
            offsetWithinPage: offsetWithinPage,
            isValidPage: isValidPageIndex,
            itemIndexForPage: itemIndex(forPageIndex:),
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

      func scrollToPage(_ pageIndex: Int, animated: Bool) {
        guard let collectionView = collectionView, isValidPageIndex(pageIndex) else { return }
        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return }

        let indexPath = IndexPath(item: itemIndex, section: 0)

        if collectionView.contentSize.height > 0 {
          isProgrammaticAnimatedScroll = animated
          collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        } else {
          guard let pageID = scrollEngine.pageID(forPageIndex: pageIndex, viewModel: viewModel) else {
            return
          }
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
        guard let pageIndex = pageIndex(forPageID: pageID) else { return }
        guard let collectionView = collectionView,
          isValidPageIndex(pageIndex),
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

        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return }
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
          guard let pageIndex = pageIndex(forPageID: pageID) else {
            return UICollectionViewCell()
          }

          let item = collectionView.dequeueReusableCell(
            withReuseIdentifier: "WebtoonPageCell",
            for: indexPath
          )
          guard let cell = item as? WebtoonPageCell else {
            assertionFailure("Failed to dequeue WebtoonPageCell")
            return item
          }
          cell.readerBackground = readerBackground

          let preloadedImage = viewModel?.preloadedImage(forPageIndex: pageIndex)
          let displayedPageNumber = viewModel?.displayPageNumber(forPageIndex: pageIndex)

          if preloadedImage == nil {
            Task { @MainActor [weak self] in
              guard let self = self else { return }
              await self.loadImageForPage(pageIndex)
            }
          }

          cell.configure(
            pageIndex: pageIndex,
            displayPageNumber: displayedPageNumber,
            image: preloadedImage,
            showPageNumber: showPageNumber,
            loadImage: { [weak self] index in
              guard let self = self else { return }
              if let image = self.viewModel?.preloadedImage(forPageIndex: index) {
                if let collectionView = self.collectionView,
                  let itemIndex = self.itemIndex(forPageIndex: index),
                  let cell = collectionView.cellForItem(at: IndexPath(item: itemIndex, section: 0))
                    as? WebtoonPageCell
                {
                  cell.setImage(image)
                }
                return
              }

              Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.loadImageForPage(index)
              }
            }
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
          guard let pageIndex = pageIndex(forPageID: pageID) else {
            return CGSize(width: pageWidth, height: pageWidth * 3)
          }
          guard let page = viewModel?.page(at: pageIndex) else {
            return CGSize(width: pageWidth, height: pageWidth * 3)
          }
          let height = heightCache.height(for: pageIndex, page: page, pageWidth: pageWidth)
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
          let resolvedPageIndex = scrollEngine.resolvedPageIndex(
            forItemIndex: newCurrentItemIndex,
            viewModel: viewModel
          )
        else {
          return
        }

        if scrollEngine.currentPage != resolvedPageIndex {
          scrollEngine.currentPage = resolvedPageIndex
          scrollEngine.currentPageID = scrollEngine.pageID(
            forPageIndex: resolvedPageIndex,
            viewModel: viewModel
          )
          onPageChange?(resolvedPageIndex)
        }
      }

      // MARK: - Image Loading

      @MainActor
      func loadImageForPage(_ pageIndex: Int) async {
        guard isValidPageIndex(pageIndex),
          let viewModel = viewModel
        else {
          return
        }

        // First check if image is already preloaded
        if let preloadedImage = viewModel.preloadedImage(forPageIndex: pageIndex) {
          pageCell(forPageIndex: pageIndex)?.setImage(preloadedImage)
          return
        }

        if let image = await viewModel.preloadImageForPage(at: pageIndex) {
          pageCell(forPageIndex: pageIndex)?.setImage(image)
        } else {
          showImageError(for: pageIndex)
        }
      }

      private func pageCell(forPageIndex pageIndex: Int) -> WebtoonPageCell? {
        guard let collectionView else { return nil }
        guard let indexPath = indexPath(forPageIndex: pageIndex) else { return nil }
        return collectionView.cellForItem(at: indexPath) as? WebtoonPageCell
      }

      private func showImageError(for pageIndex: Int) {
        pageCell(forPageIndex: pageIndex)?.showError()
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
        onZoomRequest?(result.pageIndex, result.anchor)
      }

      private func pageIndexAndAnchor(for location: CGPoint) -> (pageIndex: Int, anchor: CGPoint)? {
        guard let collectionView = collectionView else { return nil }
        let totalPages = self.pageCount

        if let indexPath = collectionView.indexPathForItem(at: location),
          let pageIndex = scrollEngine.resolvedPageIndex(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          ),
          isValidPageIndex(pageIndex)
        {
          if let cell = collectionView.cellForItem(at: indexPath) {
            let local = cell.contentView.convert(location, from: collectionView)
            return (pageIndex, normalizedAnchor(in: cell.contentView.bounds, location: local))
          }
          if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
            return (pageIndex, normalizedAnchor(in: attributes.frame, location: location))
          }
        }

        guard totalPages > 0 else { return nil }
        let fallback = min(max(scrollEngine.currentPage, 0), totalPages - 1)
        guard isValidPageIndex(fallback) else { return nil }
        guard let fallbackIndexPath = indexPath(forPageIndex: fallback) else { return nil }
        if let cell = collectionView.cellForItem(at: fallbackIndexPath) {
          let local = cell.contentView.convert(location, from: collectionView)
          return (fallback, normalizedAnchor(in: cell.contentView.bounds, location: local))
        }
        if let attributes = collectionView.layoutAttributesForItem(at: fallbackIndexPath) {
          return (fallback, normalizedAnchor(in: attributes.frame, location: location))
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
          let targetIndex = scrollEngine.resolvedPageIndex(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          ),
          isValidPageIndex(targetIndex)
        else { return }
        let indices = WebtoonContentItems.preheatPageIndices(around: targetIndex)
        Task { @MainActor [weak self] in
          for index in indices where self?.isValidPageIndex(index) == true {
            await self?.loadImageForPage(index)
          }
        }
      }
    }
  }
#endif
