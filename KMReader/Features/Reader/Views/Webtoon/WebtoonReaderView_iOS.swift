//
//  WebtoonReaderView_iOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI
  import UIKit

  struct WebtoonReaderView: UIViewRepresentable {
    let pages: [BookPage]
    let viewModel: ReaderViewModel
    let onPageChange: ((Int) -> Void)?
    let onCenterTap: (() -> Void)?
    let onScrollToBottom: ((Bool) -> Void)?
    let onNextBookPanUpdate: ((CGFloat) -> Void)?
    let onNextBookPanEnd: ((CGFloat) -> Void)?
    let onZoomRequest: ((Int, CGPoint) -> Void)?
    let pageWidth: CGFloat
    let readerBackground: ReaderBackground
    let tapZoneMode: TapZoneMode
    let doubleTapZoomMode: DoubleTapZoomMode
    let showPageNumber: Bool

    init(
      pages: [BookPage], viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      readerBackground: ReaderBackground,
      tapZoneMode: TapZoneMode = .auto,
      doubleTapZoomMode: DoubleTapZoomMode = .fast,
      showPageNumber: Bool = true,
      onPageChange: ((Int) -> Void)? = nil,
      onCenterTap: (() -> Void)? = nil,
      onScrollToBottom: ((Bool) -> Void)? = nil,
      onNextBookPanUpdate: ((CGFloat) -> Void)? = nil,
      onNextBookPanEnd: ((CGFloat) -> Void)? = nil,
      onZoomRequest: ((Int, CGPoint) -> Void)? = nil
    ) {
      self.pages = pages
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.readerBackground = readerBackground
      self.tapZoneMode = tapZoneMode
      self.doubleTapZoomMode = doubleTapZoomMode
      self.showPageNumber = showPageNumber
      self.onPageChange = onPageChange
      self.onCenterTap = onCenterTap
      self.onScrollToBottom = onScrollToBottom
      self.onNextBookPanUpdate = onNextBookPanUpdate
      self.onNextBookPanEnd = onNextBookPanEnd
      self.onZoomRequest = onZoomRequest
    }

    func makeUIView(context: Context) -> UICollectionView {
      let layout = WebtoonLayout()
      let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColor = UIColor(readerBackground.color)
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
      longPressGesture.minimumPressDuration = 0.5
      longPressGesture.cancelsTouchesInView = false
      longPressGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(longPressGesture)

      let pinchGesture = UIPinchGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handlePinch(_:))
      )
      pinchGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(pinchGesture)

      let nextBookPanGesture = UIPanGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleNextBookPan(_:))
      )
      nextBookPanGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(nextBookPanGesture)
      context.coordinator.nextBookPanGesture = nextBookPanGesture

      context.coordinator.collectionView = collectionView
      context.coordinator.layout = layout
      context.coordinator.scheduleInitialScroll()

      return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
      collectionView.backgroundColor = UIColor(readerBackground.color)
      context.coordinator.update(
        pages: pages,
        viewModel: viewModel,
        onPageChange: onPageChange,
        onCenterTap: onCenterTap,
        onScrollToBottom: onScrollToBottom,
        onNextBookPanUpdate: onNextBookPanUpdate,
        onNextBookPanEnd: onNextBookPanEnd,
        onZoomRequest: onZoomRequest,
        pageWidth: pageWidth,
        collectionView: collectionView,
        readerBackground: readerBackground,
        tapZoneMode: tapZoneMode,
        doubleTapZoomMode: doubleTapZoomMode,
        showPageNumber: showPageNumber
      )
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource,
      UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate
    {
      var parent: WebtoonReaderView
      var collectionView: UICollectionView?
      var layout: WebtoonLayout?
      var pages: [BookPage] = []
      var currentPage: Int = 0
      weak var viewModel: ReaderViewModel?
      var onPageChange: ((Int) -> Void)?
      var onCenterTap: (() -> Void)?
      var onScrollToBottom: ((Bool) -> Void)?
      var onNextBookPanUpdate: ((CGFloat) -> Void)?
      var onNextBookPanEnd: ((CGFloat) -> Void)?
      var onZoomRequest: ((Int, CGPoint) -> Void)?
      var nextBookPanGesture: UIPanGestureRecognizer?
      var lastPagesCount: Int = 0
      var isUserScrolling: Bool = false
      var hasScrolledToInitialPage: Bool = false
      var initialScrollRetrier = InitialScrollRetrier(
        maxRetries: WebtoonConstants.initialScrollMaxRetries
      )
      var pageWidth: CGFloat = 0
      var isAtBottom: Bool = false
      var lastTargetPageIndex: Int?
      var readerBackground: ReaderBackground = .system
      var tapZoneMode: TapZoneMode = .auto
      var doubleTapZoomMode: DoubleTapZoomMode = .fast
      var showPageNumber: Bool = true
      var isLongPress: Bool = false
      var hasTriggeredZoomGesture: Bool = false
      private var singleTapWorkItem: DispatchWorkItem?

      private let longPressThreshold: TimeInterval = 0.5

      var heightCache = WebtoonPageHeightCache()

      init(_ parent: WebtoonReaderView) {
        self.parent = parent
        self.pages = parent.pages
        self.currentPage = parent.viewModel.currentPageIndex
        self.viewModel = parent.viewModel
        self.onPageChange = parent.onPageChange
        self.onCenterTap = parent.onCenterTap
        self.onScrollToBottom = parent.onScrollToBottom
        self.onNextBookPanUpdate = parent.onNextBookPanUpdate
        self.onNextBookPanEnd = parent.onNextBookPanEnd
        self.onZoomRequest = parent.onZoomRequest
        self.lastPagesCount = parent.pages.count
        self.hasScrolledToInitialPage = false
        self.pageWidth = parent.pageWidth
        self.heightCache.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.readerBackground
        self.doubleTapZoomMode = parent.doubleTapZoomMode
      }

      // MARK: - Helper Methods

      func isValidPageIndex(_ index: Int) -> Bool {
        index >= 0 && index < pages.count
      }

      func scheduleInitialScroll() {
        initialScrollRetrier.reset()
        requestInitialScroll(currentPage, delay: WebtoonConstants.initialScrollDelay)
      }

      @MainActor
      func executeAfterDelay(
        _ delay: TimeInterval,
        _ block: @escaping () -> Void
      ) {
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          block()
        }
      }

      func requestInitialScroll(_ pageIndex: Int, delay: TimeInterval) {
        initialScrollRetrier.schedule(after: delay, using: executeAfterDelay) { [weak self] in
          guard let self = self,
            !self.hasScrolledToInitialPage,
            self.pages.count > 0,
            self.isValidPageIndex(pageIndex)
          else { return }
          self.scrollToInitialPage(pageIndex)
        }
      }

      func update(
        pages: [BookPage],
        viewModel: ReaderViewModel,
        onPageChange: ((Int) -> Void)?,
        onCenterTap: (() -> Void)?,
        onScrollToBottom: ((Bool) -> Void)?,
        onNextBookPanUpdate: ((CGFloat) -> Void)?,
        onNextBookPanEnd: ((CGFloat) -> Void)?,
        onZoomRequest: ((Int, CGPoint) -> Void)?,
        pageWidth: CGFloat,
        collectionView: UICollectionView,
        readerBackground: ReaderBackground,
        tapZoneMode: TapZoneMode,
        doubleTapZoomMode: DoubleTapZoomMode,
        showPageNumber: Bool
      ) {
        applySafeAreaInsetsIfNeeded(for: collectionView)
        self.pages = pages
        self.viewModel = viewModel
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onScrollToBottom = onScrollToBottom
        self.onNextBookPanUpdate = onNextBookPanUpdate
        self.onNextBookPanEnd = onNextBookPanEnd
        self.onZoomRequest = onZoomRequest
        self.pageWidth = pageWidth
        self.readerBackground = readerBackground
        self.tapZoneMode = tapZoneMode
        self.doubleTapZoomMode = doubleTapZoomMode
        if self.showPageNumber != showPageNumber {
          self.showPageNumber = showPageNumber
          for cell in collectionView.visibleCells {
            if let pageCell = cell as? WebtoonPageCell {
              pageCell.showPageNumber = showPageNumber
            }
          }
        }
        self.showPageNumber = showPageNumber

        let currentPage = viewModel.currentPageIndex

        if lastPagesCount != pages.count || abs(heightCache.lastPageWidth - pageWidth) > 0.1 {
          handleDataReload(collectionView: collectionView, currentPage: currentPage)
        }

        for cell in collectionView.visibleCells {
          if let pageCell = cell as? WebtoonPageCell {
            pageCell.readerBackground = readerBackground
            pageCell.showPageNumber = showPageNumber
          } else if let footerCell = cell as? WebtoonFooterCell {
            footerCell.readerBackground = readerBackground
          }
        }

        if !hasScrolledToInitialPage && pages.count > 0 && isValidPageIndex(currentPage) {
          scrollToInitialPage(currentPage)
        }

        if let targetPageIndex = viewModel.targetPageIndex,
          targetPageIndex != lastTargetPageIndex,
          isValidPageIndex(targetPageIndex)
        {
          lastTargetPageIndex = targetPageIndex
          scrollToPage(targetPageIndex, animated: true)
          viewModel.targetPageIndex = nil
          if self.currentPage != targetPageIndex {
            self.currentPage = targetPageIndex
            onPageChange?(targetPageIndex)
          }
        } else {
          if self.currentPage != currentPage {
            self.currentPage = currentPage
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

      private func handleDataReload(collectionView: UICollectionView, currentPage: Int) {
        let pagesChanged = lastPagesCount != pages.count

        if pagesChanged {
          heightCache.reset()
          initialScrollRetrier.reset()
        }

        lastPagesCount = pages.count
        hasScrolledToInitialPage = false
        initialScrollRetrier.reset()
        heightCache.rescaleIfNeeded(newWidth: pageWidth)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if isValidPageIndex(currentPage) {
          requestInitialScroll(currentPage, delay: WebtoonConstants.layoutReadyDelay)
        }
      }

      func scrollToPage(_ pageIndex: Int, animated: Bool) {
        guard let collectionView = collectionView, isValidPageIndex(pageIndex) else { return }

        let indexPath = IndexPath(item: pageIndex, section: 0)

        if collectionView.contentSize.height > 0 {
          collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        } else {
          requestScrollToPage(
            pageIndex, animated: animated, delay: WebtoonConstants.layoutReadyDelay)
        }
      }

      func requestScrollToPage(_ pageIndex: Int, animated: Bool, delay: TimeInterval) {
        executeAfterDelay(delay) { [weak self] in
          guard let self = self,
            let collectionView = self.collectionView,
            self.isValidPageIndex(pageIndex)
          else { return }
          collectionView.scrollToItem(
            at: IndexPath(item: pageIndex, section: 0),
            at: .top,
            animated: animated
          )
        }
      }

      func scrollToInitialPage(_ pageIndex: Int) {
        guard !hasScrolledToInitialPage else { return }
        guard let collectionView = collectionView,
          isValidPageIndex(pageIndex),
          collectionView.bounds.width > 0 && collectionView.bounds.height > 0
        else {
          if !hasScrolledToInitialPage {
            requestInitialScroll(pageIndex, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }

        collectionView.layoutIfNeeded()

        guard collectionView.contentSize.height > 0 else {
          if !hasScrolledToInitialPage {
            requestInitialScroll(pageIndex, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }

        let indexPath = IndexPath(item: pageIndex, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
        collectionView.layoutIfNeeded()

        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.hasScrolledToInitialPage = true
        }
      }

      // MARK: - UICollectionViewDataSource

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
        -> Int
      {
        pages.count + 1
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
      {
        if indexPath.item == pages.count {
          let item = collectionView.dequeueReusableCell(
            withReuseIdentifier: "WebtoonFooterCell",
            for: indexPath
          )
          guard let cell = item as? WebtoonFooterCell else {
            assertionFailure("Failed to dequeue WebtoonFooterCell")
            return item
          }
          cell.readerBackground = readerBackground
          return cell
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

        let pageIndex = indexPath.item
        let preloadedImage = viewModel?.preloadedImages[pageIndex]

        if preloadedImage == nil {
          Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.loadImageForPage(pageIndex)
          }
        }

        cell.configure(
          pageIndex: pageIndex,
          image: preloadedImage,
          showPageNumber: showPageNumber,
          loadImage: { [weak self] index in
            guard let self = self else { return }
            if let image = self.viewModel?.preloadedImages[index] {
              if let collectionView = self.collectionView {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
                  cell.setImage(image)
                }
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

      // MARK: - UICollectionViewDelegateFlowLayout

      func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> CGSize {
        if indexPath.item == pages.count {
          return CGSize(width: pageWidth, height: WebtoonConstants.footerHeight)
        }
        let page = pages[indexPath.item]
        let height = heightCache.height(for: indexPath.item, page: page, pageWidth: pageWidth)
        let scale = collectionView.traitCollection.displayScale
        let alignedHeight = scale > 0 ? ceil(height * scale) / scale : height
        return CGSize(width: pageWidth, height: alignedHeight)
      }

      // MARK: - UICollectionViewDelegate

      func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkIfAtBottom(scrollView)

        if isUserScrolling {
          updateCurrentPage()
        }
      }

      func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
        checkIfAtBottom(scrollView)
        updateCurrentPage()
        viewModel?.cleanupDistantImagesAroundCurrentPage()
      }

      func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
          isUserScrolling = false
          checkIfAtBottom(scrollView)
          updateCurrentPage()
          viewModel?.cleanupDistantImagesAroundCurrentPage()
        }
      }

      func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isUserScrolling = false
        checkIfAtBottom(scrollView)
        updateCurrentPage()
        viewModel?.cleanupDistantImagesAroundCurrentPage()
      }

      private func checkIfAtBottom(_ scrollView: UIScrollView) {
        guard hasScrolledToInitialPage else {
          return
        }

        let contentHeight = scrollView.contentSize.height
        let scrollOffset = scrollView.contentOffset.y
        let scrollViewHeight = scrollView.bounds.height

        guard contentHeight > scrollViewHeight else {
          return
        }

        let isAtBottomNow =
          scrollOffset + scrollViewHeight >= contentHeight - WebtoonConstants.bottomThreshold

        if isAtBottomNow != isAtBottom {
          isAtBottom = isAtBottomNow
          onScrollToBottom?(isAtBottom)
        }
      }

      private func updateCurrentPage() {
        guard let collectionView = collectionView else { return }

        // When at bottom (showing end page), set currentPage to pages.count to show "END"
        if isAtBottom {
          if currentPage != pages.count {
            currentPage = pages.count
            onPageChange?(pages.count)
          }
          return
        }

        let scrollOffset = collectionView.contentOffset.y
        let scrollViewHeight = collectionView.bounds.height
        let viewportBottom = scrollOffset + scrollViewHeight

        // Find the page whose bottom edge just passed the viewport bottom (with threshold)
        // This means: find the highest page index where page.bottom <= viewportBottom + threshold
        var newCurrentPage = 0
        for pageIndex in 0..<pages.count {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
            continue
          }
          // Page is considered "read" when its bottom passes the viewport bottom
          if frame.maxY <= viewportBottom + WebtoonConstants.bottomThreshold {
            newCurrentPage = pageIndex
          } else {
            break
          }
        }

        if currentPage != newCurrentPage {
          currentPage = newCurrentPage
          onPageChange?(newCurrentPage)
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

        let page = pages[pageIndex]

        // First check if image is already preloaded
        if let preloadedImage = viewModel.preloadedImages[pageIndex] {
          if let collectionView = collectionView {
            let indexPath = IndexPath(item: pageIndex, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
              cell.setImage(preloadedImage)
            }
          }
          return
        }

        if let image = await viewModel.preloadImageForPage(page) {
          if let collectionView = collectionView {
            let indexPath = IndexPath(item: pageIndex, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
              cell.setImage(image)
            }
          }
        } else {
          showImageError(for: pageIndex)
        }
      }

      private func showImageError(for pageIndex: Int) {
        guard let collectionView = collectionView else { return }
        let indexPath = IndexPath(item: pageIndex, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
          cell.showError()
        }
      }

      // MARK: - Tap Gesture Handling

      @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPress = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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
          zoneThreshold: AppConfig.tapZoneSize.value
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

      @objc func handleNextBookPan(_ gesture: UIPanGestureRecognizer) {
        guard isAtBottom else { return }
        guard let view = gesture.view else { return }

        let translation = gesture.translation(in: view).y

        // Only handle upward pan (negative y)
        if gesture.state == .changed {
          if translation < 0 {
            onNextBookPanUpdate?(translation)
          }
        } else if gesture.state == .ended || gesture.state == .cancelled {
          onNextBookPanEnd?(translation)
        }
      }

      // MARK: - UIGestureRecognizerDelegate

      func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
      ) -> Bool {
        // Always allow simultaneous recognition to ensure scrolling and context menus work.
        return true
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == nextBookPanGesture else { return true }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

        // Only recognize if at bottom and swiping up
        guard isAtBottom else { return false }

        let velocity = pan.velocity(in: pan.view)
        // Only allow upward pan (negative y velocity)
        return velocity.y < 0 && abs(velocity.y) > abs(velocity.x)
      }

      private func requestZoom(at location: CGPoint) {
        guard let result = pageIndexAndAnchor(for: location) else { return }
        onZoomRequest?(result.pageIndex, result.anchor)
      }

      private func pageIndexAndAnchor(for location: CGPoint) -> (pageIndex: Int, anchor: CGPoint)? {
        guard let collectionView = collectionView else { return nil }

        if let indexPath = collectionView.indexPathForItem(at: location),
          isValidPageIndex(indexPath.item)
        {
          if let cell = collectionView.cellForItem(at: indexPath) {
            let local = cell.contentView.convert(location, from: collectionView)
            return (indexPath.item, normalizedAnchor(in: cell.contentView.bounds, location: local))
          }
          if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
            return (indexPath.item, normalizedAnchor(in: attributes.frame, location: location))
          }
        }

        guard !pages.isEmpty else { return nil }
        let fallback = min(max(currentPage, 0), pages.count - 1)
        guard isValidPageIndex(fallback) else { return nil }
        let fallbackIndexPath = IndexPath(item: fallback, section: 0)
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
        preheatPages(at: targetOffset, in: collectionView)
        collectionView.layoutIfNeeded()
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }

      private func scrollDown(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetOffset = min(
          currentOffset + scrollAmount,
          collectionView.contentSize.height - screenHeight
        )
        preheatPages(at: targetOffset, in: collectionView)
        collectionView.layoutIfNeeded()
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }

      private func preheatPages(at targetOffset: CGFloat, in collectionView: UICollectionView) {
        let centerY = targetOffset + collectionView.bounds.height / 2
        let centerPoint = CGPoint(x: collectionView.bounds.width / 2, y: centerY)
        guard let indexPath = collectionView.indexPathForItem(at: centerPoint),
          isValidPageIndex(indexPath.item)
        else { return }
        let targetIndex = indexPath.item
        let indices = [
          targetIndex - 2, targetIndex - 1, targetIndex, targetIndex + 1, targetIndex + 2,
        ]
        Task { @MainActor [weak self] in
          for index in indices where self?.isValidPageIndex(index) == true {
            await self?.loadImageForPage(index)
          }
        }
      }
    }
  }
#endif
