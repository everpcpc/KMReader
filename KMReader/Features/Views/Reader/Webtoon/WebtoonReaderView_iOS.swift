//
//  WebtoonReaderView_iOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import ImageIO
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
    let pageWidth: CGFloat
    let readerBackground: ReaderBackground
    let disableTapToTurnPage: Bool

    init(
      pages: [BookPage], viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      readerBackground: ReaderBackground,
      disableTapToTurnPage: Bool = false,
      onPageChange: ((Int) -> Void)? = nil,
      onCenterTap: (() -> Void)? = nil,
      onScrollToBottom: ((Bool) -> Void)? = nil,
      onNextBookPanUpdate: ((CGFloat) -> Void)? = nil,
      onNextBookPanEnd: ((CGFloat) -> Void)? = nil
    ) {
      self.pages = pages
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.readerBackground = readerBackground
      self.disableTapToTurnPage = disableTapToTurnPage
      self.onPageChange = onPageChange
      self.onCenterTap = onCenterTap
      self.onScrollToBottom = onScrollToBottom
      self.onNextBookPanUpdate = onNextBookPanUpdate
      self.onNextBookPanEnd = onNextBookPanEnd
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
      collectionView.isPrefetchingEnabled = true

      collectionView.register(WebtoonPageCell.self, forCellWithReuseIdentifier: "WebtoonPageCell")
      collectionView.register(
        WebtoonFooterCell.self, forCellWithReuseIdentifier: "WebtoonFooterCell")

      let tapGesture = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleTap(_:))
      )
      tapGesture.numberOfTapsRequired = 1
      collectionView.addGestureRecognizer(tapGesture)

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
        pageWidth: pageWidth,
        collectionView: collectionView,
        readerBackground: readerBackground,
        disableTapToTurnPage: disableTapToTurnPage
      )
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

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
      var nextBookPanGesture: UIPanGestureRecognizer?
      var lastPagesCount: Int = 0
      var isUserScrolling: Bool = false
      var hasScrolledToInitialPage: Bool = false
      var lastPreloadTime: Date?
      var pageWidth: CGFloat = 0
      var lastPageWidth: CGFloat = 0
      var isAtBottom: Bool = false
      var lastVisibleCellsUpdateTime: Date?
      var lastTargetPageIndex: Int?
      var readerBackground: ReaderBackground = .system
      var disableTapToTurnPage: Bool = false

      var pageHeights: [Int: CGFloat] = [:]
      var loadingPages: Set<Int> = []

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
        self.lastPagesCount = parent.pages.count
        self.hasScrolledToInitialPage = false
        self.pageWidth = parent.pageWidth
        self.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.readerBackground
      }

      // MARK: - Helper Methods

      func isValidPageIndex(_ index: Int) -> Bool {
        index >= 0 && index < pages.count
      }

      func placeholderHeight(for index: Int) -> CGFloat {
        guard pageWidth > 0 else { return 0 }

        if let cached = pageHeights[index] {
          return cached
        }

        if index < pages.count,
          let widthValue = pages[index].width,
          let heightValue = pages[index].height,
          widthValue > 0
        {
          let aspectRatio = CGFloat(heightValue) / CGFloat(widthValue)
          if aspectRatio.isFinite && aspectRatio > 0 {
            return pageWidth * aspectRatio
          }
        }

        return pageWidth * 3
      }

      func applyMetadataHeights() {
        guard pageWidth > 0 else { return }

        for (index, page) in pages.enumerated() {
          guard let widthValue = page.width,
            let heightValue = page.height,
            widthValue > 0
          else {
            continue
          }

          let aspectRatio = CGFloat(heightValue) / CGFloat(widthValue)
          guard aspectRatio.isFinite && aspectRatio > 0 else { continue }

          let targetHeight = pageWidth * aspectRatio
          if pageHeights[index] == nil {
            pageHeights[index] = targetHeight
          }
        }
      }

      func scheduleInitialScroll() {
        DispatchQueue.main.asyncAfter(deadline: .now() + WebtoonConstants.initialScrollDelay) {
          [weak self] in
          guard let self = self,
            !self.hasScrolledToInitialPage,
            self.pages.count > 0,
            self.isValidPageIndex(self.currentPage)
          else { return }
          self.scrollToInitialPage(self.currentPage)
        }
      }

      func executeAfterDelay(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
      }

      func calculateOffsetToPage(_ pageIndex: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<pageIndex {
          if let height = pageHeights[i] {
            offset += height
          } else {
            offset += placeholderHeight(for: i)
          }
        }
        return offset
      }

      func update(
        pages: [BookPage],
        viewModel: ReaderViewModel,
        onPageChange: ((Int) -> Void)?,
        onCenterTap: (() -> Void)?,
        onScrollToBottom: ((Bool) -> Void)?,
        onNextBookPanUpdate: ((CGFloat) -> Void)?,
        onNextBookPanEnd: ((CGFloat) -> Void)?,
        pageWidth: CGFloat,
        collectionView: UICollectionView,
        readerBackground: ReaderBackground,
        disableTapToTurnPage: Bool
      ) {
        self.pages = pages
        self.viewModel = viewModel
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onScrollToBottom = onScrollToBottom
        self.onNextBookPanUpdate = onNextBookPanUpdate
        self.onNextBookPanEnd = onNextBookPanEnd
        self.pageWidth = pageWidth
        self.readerBackground = readerBackground
        self.disableTapToTurnPage = disableTapToTurnPage
        applyMetadataHeights()

        let currentPage = viewModel.currentPageIndex

        if lastPagesCount != pages.count || abs(lastPageWidth - pageWidth) > 0.1 {
          handleDataReload(collectionView: collectionView, currentPage: currentPage)
        }

        for cell in collectionView.visibleCells {
          if let pageCell = cell as? WebtoonPageCell {
            pageCell.readerBackground = readerBackground
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

      private func handleDataReload(collectionView: UICollectionView, currentPage: Int) {
        let pagesChanged = lastPagesCount != pages.count
        let previousWidth = lastPageWidth

        if pagesChanged {
          pageHeights.removeAll()
        } else if previousWidth > 0 && abs(previousWidth - pageWidth) > 0.1 {
          let scaleFactor = pageWidth / previousWidth
          if scaleFactor.isFinite && scaleFactor > 0 {
            for (index, height) in pageHeights {
              pageHeights[index] = height * scaleFactor
            }
          }
        }

        applyMetadataHeights()

        lastPagesCount = pages.count
        lastPageWidth = pageWidth
        hasScrolledToInitialPage = false
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if isValidPageIndex(currentPage) {
          executeAfterDelay(WebtoonConstants.layoutReadyDelay) { [weak self] in
            self?.scrollToInitialPage(currentPage)
          }
          executeAfterDelay(0.5) { [weak self] in
            guard let self = self, !self.hasScrolledToInitialPage else { return }
            self.scrollToInitialPage(currentPage)
          }
        }
      }

      func scrollToPage(_ pageIndex: Int, animated: Bool) {
        guard let collectionView = collectionView, isValidPageIndex(pageIndex) else { return }

        let indexPath = IndexPath(item: pageIndex, section: 0)

        if collectionView.contentSize.height > 0 {
          collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        } else {
          DispatchQueue.main.async { [weak self] in
            guard let self = self, let collectionView = self.collectionView else { return }
            if collectionView.contentSize.height > 0 {
              collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
            } else {
              let offset = self.calculateOffsetToPage(pageIndex)
              collectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
            }
          }
        }
      }

      func scrollToInitialPage(_ pageIndex: Int) {
        guard !hasScrolledToInitialPage else { return }
        guard let collectionView = collectionView,
          isValidPageIndex(pageIndex),
          collectionView.bounds.width > 0 && collectionView.bounds.height > 0
        else {
          if !hasScrolledToInitialPage {
            executeAfterDelay(0.1) { [weak self] in
              self?.scrollToInitialPage(pageIndex)
            }
          }
          return
        }

        collectionView.layoutIfNeeded()

        guard collectionView.contentSize.height > 0 else {
          if !hasScrolledToInitialPage {
            executeAfterDelay(WebtoonConstants.layoutReadyDelay) { [weak self] in
              self?.scrollToInitialPage(pageIndex)
            }
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
          let cell =
            collectionView.dequeueReusableCell(
              withReuseIdentifier: "WebtoonFooterCell", for: indexPath)
            as! WebtoonFooterCell
          cell.readerBackground = readerBackground
          return cell
        }

        let cell =
          collectionView.dequeueReusableCell(withReuseIdentifier: "WebtoonPageCell", for: indexPath)
          as! WebtoonPageCell
        cell.readerBackground = readerBackground

        let pageIndex = indexPath.item

        Task { @MainActor [weak self] in
          guard let self = self else { return }
          await self.loadImageForPage(pageIndex)
        }

        cell.configure(
          pageIndex: pageIndex,
          image: nil,
          loadImage: { [weak self] index in
            guard let self = self else { return }
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

        if let height = pageHeights[indexPath.item] {
          return CGSize(width: pageWidth, height: height)
        }

        return CGSize(width: pageWidth, height: pageWidth)
      }

      // MARK: - UICollectionViewDelegate

      func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkIfAtBottom(scrollView)

        if isUserScrolling {
          updateCurrentPage()
          throttlePreload()
        }
      }

      private func throttlePreload() {
        let now = Date()
        if lastPreloadTime == nil
          || now.timeIntervalSince(lastPreloadTime!) > WebtoonConstants.preloadThrottleInterval
        {
          lastPreloadTime = now
          preloadNearbyPages()
        }
      }

      func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
        checkIfAtBottom(scrollView)
        updateCurrentPage()
        preloadNearbyPages()
      }

      func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
          isUserScrolling = false
          checkIfAtBottom(scrollView)
          updateCurrentPage()
          preloadNearbyPages()
        }
      }

      func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isUserScrolling = false
        checkIfAtBottom(scrollView)
        updateCurrentPage()
        preloadNearbyPages()
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

          if isAtBottomNow && pages.count > 0 {
            let lastPageIndex = pages.count - 1
            if let collectionView = collectionView {
              let visibleIndexPaths = collectionView.indexPathsForVisibleItems
                .filter { $0.item < pages.count }
              if visibleIndexPaths.contains(where: { $0.item == lastPageIndex }) {
                if currentPage != lastPageIndex {
                  currentPage = lastPageIndex
                  onPageChange?(lastPageIndex)
                }
              }
            }
          }
        }
      }

      private func updateCurrentPage() {
        guard let collectionView = collectionView else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
          .filter { $0.item < pages.count }
          .sorted { $0.item < $1.item }

        if pages.count > 0 {
          let lastPageIndex = pages.count - 1
          if visibleIndexPaths.contains(where: { $0.item == lastPageIndex }) {
            let contentHeight = collectionView.contentSize.height
            let scrollOffset = collectionView.contentOffset.y
            let scrollViewHeight = collectionView.bounds.height

            if scrollOffset + scrollViewHeight >= contentHeight - WebtoonConstants.bottomThreshold {
              if currentPage != lastPageIndex {
                currentPage = lastPageIndex
                onPageChange?(lastPageIndex)
                return
              }
            }
          }
        }

        let centerY = collectionView.contentOffset.y + collectionView.bounds.height / 2
        let centerPoint = CGPoint(x: collectionView.bounds.width / 2, y: centerY)

        if let indexPath = collectionView.indexPathForItem(at: centerPoint),
          indexPath.item != pages.count,
          indexPath.item != currentPage,
          isValidPageIndex(indexPath.item)
        {
          currentPage = indexPath.item
          onPageChange?(indexPath.item)
        } else {
          if let firstVisible = visibleIndexPaths.first {
            let midIndex = firstVisible.item + visibleIndexPaths.count / 2
            if isValidPageIndex(midIndex) && midIndex != currentPage {
              currentPage = midIndex
              onPageChange?(midIndex)
            }
          }
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
        if let preloadedImage = viewModel.preloadedImages[page.number] {
          if let collectionView = collectionView {
            let indexPath = IndexPath(item: pageIndex, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
              cell.setImage(preloadedImage)
            }
          }

          let size = preloadedImage.size
          let aspectRatio = size.height / size.width
          let height = pageWidth * aspectRatio
          let oldHeight = pageHeights[pageIndex] ?? pageWidth
          pageHeights[pageIndex] = height
          updateLayoutIfNeeded(pageIndex: pageIndex, height: height, oldHeight: oldHeight)
          return
        }

        // Fall back to loading from file
        guard let imageURL = await viewModel.getPageImageFileURL(page: page) else {
          showImageError(for: pageIndex)
          return
        }

        // Load image and get size in one operation
        var imageSize: CGSize?
        if let collectionView = collectionView {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
            imageSize = await cell.loadImageFromURL(imageURL)
          }
        }

        if let size = imageSize {
          let aspectRatio = size.height / size.width
          let height = pageWidth * aspectRatio
          let oldHeight = pageHeights[pageIndex] ?? pageWidth
          pageHeights[pageIndex] = height

          updateLayoutIfNeeded(pageIndex: pageIndex, height: height, oldHeight: oldHeight)
          tryScrollToInitialPageIfNeeded(pageIndex: pageIndex)
        }
      }

      private func updateLayoutIfNeeded(pageIndex: Int, height: CGFloat, oldHeight: CGFloat) {
        let heightDiff = abs(height - oldHeight)

        if let collectionView = collectionView, let layout = layout {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          let isVisible = collectionView.indexPathsForVisibleItems.contains(indexPath)

          if isVisible {
            layout.invalidateLayout()
            collectionView.layoutIfNeeded()
          } else if heightDiff > WebtoonConstants.heightChangeThreshold {
            if !isUserScrolling {
              applyHeightChangeIfNeeded(pageIndex: pageIndex, oldHeight: oldHeight)
            } else {
              scheduleDeferredHeightUpdate(pageIndex: pageIndex, oldHeight: oldHeight)
            }
          }
        }
      }

      private func tryScrollToInitialPageIfNeeded(pageIndex: Int) {
        guard !hasScrolledToInitialPage,
          isValidPageIndex(currentPage),
          abs(pageIndex - currentPage) <= 3
        else { return }
        let targetPage = currentPage
        executeAfterDelay(0.1) { [weak self] in
          self?.scrollToInitialPage(targetPage)
        }
      }

      private func showImageError(for pageIndex: Int) {
        guard let collectionView = collectionView else { return }
        let indexPath = IndexPath(item: pageIndex, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
          cell.showError()
        }
      }

      private func applyHeightChangeIfNeeded(pageIndex: Int, oldHeight: CGFloat) {
        guard let collectionView = collectionView, let layout = layout else { return }
        let currentHeight = pageHeights[pageIndex] ?? oldHeight
        let heightDiff = abs(currentHeight - oldHeight)
        guard heightDiff > WebtoonConstants.heightChangeThreshold else { return }

        let currentOffset = collectionView.contentOffset.y
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        if pageIndex < currentPage {
          let newOffset = max(0, currentOffset + (currentHeight - oldHeight))
          UIView.performWithoutAnimation {
            collectionView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
          }
        }
      }

      private func scheduleDeferredHeightUpdate(pageIndex: Int, oldHeight: CGFloat) {
        executeAfterDelay(0.2) { [weak self] in
          guard let self = self else { return }
          let currentHeight = self.pageHeights[pageIndex] ?? oldHeight
          guard abs(currentHeight - oldHeight) > WebtoonConstants.heightChangeThreshold else {
            return
          }

          if self.isUserScrolling {
            self.scheduleDeferredHeightUpdate(pageIndex: pageIndex, oldHeight: oldHeight)
            return
          }

          self.applyHeightChangeIfNeeded(pageIndex: pageIndex, oldHeight: oldHeight)
        }
      }

      func preloadNearbyPages() {
        guard let collectionView = collectionView else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return }

        let visibleIndices = Set(visibleIndexPaths.map { $0.item })

        let minVisible = visibleIndices.min() ?? 0
        let maxVisible = visibleIndices.max() ?? pages.count - 1

        Task { @MainActor [weak self] in
          guard let self = self,
            let viewModel = self.viewModel
          else { return }

          for i in max(0, minVisible - 2)...min(self.pages.count - 1, maxVisible + 2) {
            let page = self.pages[i]
            // Skip if already preloaded
            if viewModel.preloadedImages[page.number] != nil {
              continue
            }
            if let fileURL = await viewModel.getPageImageFileURL(page: page) {
              // Load and decode image
              if let data = try? Data(contentsOf: fileURL) {
                #if os(iOS)
                  if let image = UIImage(data: data) {
                    viewModel.preloadedImages[page.number] = image
                  }
                #endif
              }
            }
          }
        }
      }

      // MARK: - Tap Gesture Handling

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let collectionView = collectionView,
          let view = collectionView.superview
        else { return }

        if disableTapToTurnPage {
          onCenterTap?()
          return
        }

        let location = gesture.location(in: view)
        let screenHeight = view.bounds.height
        let screenWidth = view.bounds.width

        let tapArea = determineTapArea(
          location: location, screenWidth: screenWidth, screenHeight: screenHeight)

        switch tapArea {
        case .center:
          handleCenterTap(collectionView: collectionView)
        case .topLeft:
          scrollUp(collectionView: collectionView, screenHeight: screenHeight)
        case .bottomRight:
          scrollDown(collectionView: collectionView, screenHeight: screenHeight)
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
        // Allow pan gesture to work simultaneously with scroll
        if gestureRecognizer == nextBookPanGesture {
          return true
        }
        return false
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

      private enum TapArea {
        case center
        case topLeft
        case bottomRight
      }

      private func determineTapArea(location: CGPoint, screenWidth: CGFloat, screenHeight: CGFloat)
        -> TapArea
      {
        let isTopArea = location.y < screenHeight * WebtoonConstants.topAreaThreshold
        let isBottomArea = location.y > screenHeight * WebtoonConstants.bottomAreaThreshold
        let isMiddleArea = !isTopArea && !isBottomArea
        let isLeftArea = location.x < screenWidth * WebtoonConstants.topAreaThreshold

        let isCenterArea =
          location.x > screenWidth * WebtoonConstants.centerAreaMin
          && location.x < screenWidth * WebtoonConstants.centerAreaMax
          && location.y > screenHeight * WebtoonConstants.centerAreaMin
          && location.y < screenHeight * WebtoonConstants.centerAreaMax

        if isCenterArea {
          return .center
        } else if isTopArea || (isMiddleArea && isLeftArea) {
          return .topLeft
        } else {
          return .bottomRight
        }
      }

      private func handleCenterTap(collectionView: UICollectionView) {
        onCenterTap?()
      }

      private func scrollUp(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetOffset = max(currentOffset - scrollAmount, 0)
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }

      private func scrollDown(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetOffset = min(
          currentOffset + scrollAmount,
          collectionView.contentSize.height - screenHeight
        )
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }
    }
  }
#endif
