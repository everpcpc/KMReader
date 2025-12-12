//
//  WebtoonReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import ImageIO
  import SDWebImage
  import SwiftUI
  import UIKit

  struct WebtoonReaderView: UIViewRepresentable {
    let pages: [BookPage]
    let viewModel: ReaderViewModel
    let onPageChange: ((Int) -> Void)?
    let onCenterTap: (() -> Void)?
    let onScrollToBottom: ((Bool) -> Void)?
    let pageWidth: CGFloat
    let readerBackground: ReaderBackground

    init(
      pages: [BookPage], viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      readerBackground: ReaderBackground,
      onPageChange: ((Int) -> Void)? = nil,
      onCenterTap: (() -> Void)? = nil,
      onScrollToBottom: ((Bool) -> Void)? = nil
    ) {
      self.pages = pages
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.readerBackground = readerBackground
      self.onPageChange = onPageChange
      self.onCenterTap = onCenterTap
      self.onScrollToBottom = onScrollToBottom
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
        pageWidth: pageWidth,
        collectionView: collectionView,
        readerBackground: readerBackground
      )
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource,
      UICollectionViewDelegateFlowLayout
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
        self.lastPagesCount = parent.pages.count
        self.hasScrolledToInitialPage = false
        self.pageWidth = parent.pageWidth
        self.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.readerBackground
      }

      // MARK: - Helper Methods

      /// Validates if a page index is within valid range
      func isValidPageIndex(_ index: Int) -> Bool {
        index >= 0 && index < pages.count
      }

      /// Calculates placeholder height using real metadata when available
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

      /// Pre-fills height cache using metadata so cells start at correct size
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

      /// Schedules initial scroll after view appears
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

      /// Executes code after a delay
      func executeAfterDelay(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
      }

      /// Calculates offset to a page index
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

      /// Updates coordinator state and handles view updates
      func update(
        pages: [BookPage],
        viewModel: ReaderViewModel,
        onPageChange: ((Int) -> Void)?,
        onCenterTap: (() -> Void)?,
        onScrollToBottom: ((Bool) -> Void)?,
        pageWidth: CGFloat,
        collectionView: UICollectionView,
        readerBackground: ReaderBackground
      ) {
        self.pages = pages
        self.viewModel = viewModel
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onScrollToBottom = onScrollToBottom
        self.pageWidth = pageWidth
        self.readerBackground = readerBackground
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

        // Handle targetPageIndex changes
        if let targetPageIndex = viewModel.targetPageIndex,
          targetPageIndex != lastTargetPageIndex,
          isValidPageIndex(targetPageIndex)
        {
          lastTargetPageIndex = targetPageIndex
          scrollToPage(targetPageIndex, animated: true)
          // Clear targetPageIndex after scrolling
          viewModel.targetPageIndex = nil
          // Update currentPageIndex
          if self.currentPage != targetPageIndex {
            self.currentPage = targetPageIndex
            onPageChange?(targetPageIndex)
          }
        } else {
          // Sync currentPage from viewModel
          if self.currentPage != currentPage {
            self.currentPage = currentPage
          }
        }

        // Layout updates handled via UICollectionViewFlowLayout invalidations
      }

      /// Handles data reload when pages count or width changes
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

      /// Throttles preload calls to avoid too frequent updates
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
        guard let imageURL = await viewModel.getPageImageFileURL(page: page) else {
          showImageError(for: pageIndex)
          return
        }

        let isFromCache = await viewModel.pageImageCache.hasImage(
          bookId: viewModel.bookId,
          page: page
        )

        let imageSize = await getImageSize(from: imageURL)

        if let collectionView = collectionView {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
            cell.setImageURL(imageURL, imageSize: imageSize)
          }
        }

        if let size = imageSize {
          let aspectRatio = size.height / size.width
          let height = pageWidth * aspectRatio
          let oldHeight = pageHeights[pageIndex] ?? pageWidth
          pageHeights[pageIndex] = height

          updateLayoutIfNeeded(pageIndex: pageIndex, height: height, oldHeight: oldHeight)

          if !isFromCache {
            tryScrollToInitialPageIfNeeded(pageIndex: pageIndex)
          }
        }
      }

      /// Get image size from URL without fully loading the image
      private func getImageSize(from url: URL) async -> CGSize? {
        if let cacheKey = SDImageCacheProvider.pageImageManager.cacheKey(for: url),
          let cachedImage = SDImageCacheProvider.pageImageCache.imageFromCache(forKey: cacheKey)
        {
          return cachedImage.size
        }
        return await Task.detached {
          if url.isFileURL {
            guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil)
            else {
              return nil
            }

            guard
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat
            else {
              return nil
            }

            return CGSize(width: width, height: height)
          }

          return nil
        }.value
      }

      /// Updates layout if height changed significantly
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

      /// Tries to scroll to initial page if needed
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

      /// Shows error state for failed image load
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

      // Preload nearby pages
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
            if !(await viewModel.pageImageCache.hasImage(bookId: viewModel.bookId, page: page)) {
              await self.loadImageForPage(i)
            }
          }
        }
      }

      // MARK: - Tap Gesture Handling

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let collectionView = collectionView,
          let view = collectionView.superview
        else { return }

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

      /// Determines which area was tapped
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

      /// Handles center tap to toggle controls
      private func handleCenterTap(collectionView: UICollectionView) {
        onCenterTap?()
      }

      /// Scrolls up
      private func scrollUp(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * WebtoonConstants.scrollAmountMultiplier
        let targetOffset = max(currentOffset - scrollAmount, 0)
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }

      /// Scrolls down
      private func scrollDown(collectionView: UICollectionView, screenHeight: CGFloat) {
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * WebtoonConstants.scrollAmountMultiplier
        let targetOffset = min(
          currentOffset + scrollAmount,
          collectionView.contentSize.height - screenHeight
        )
        collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
      }
    }
  }

#elseif os(macOS)
  import AppKit
  import ImageIO
  import SDWebImage
  import SwiftUI

  struct WebtoonReaderView: NSViewRepresentable {
    let pages: [BookPage]
    let viewModel: ReaderViewModel
    let onPageChange: ((Int) -> Void)?
    let onCenterTap: (() -> Void)?
    let onScrollToBottom: ((Bool) -> Void)?
    let pageWidth: CGFloat
    let readerBackground: ReaderBackground

    init(
      pages: [BookPage], viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      readerBackground: ReaderBackground,
      onPageChange: ((Int) -> Void)? = nil,
      onCenterTap: (() -> Void)? = nil,
      onScrollToBottom: ((Bool) -> Void)? = nil
    ) {
      self.pages = pages
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.readerBackground = readerBackground
      self.onPageChange = onPageChange
      self.onCenterTap = onCenterTap
      self.onScrollToBottom = onScrollToBottom
    }

    func makeNSView(context: Context) -> NSScrollView {
      let layout = WebtoonLayout()
      let collectionView = NSCollectionView()
      collectionView.collectionViewLayout = layout
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColors = [NSColor(readerBackground.color)]
      collectionView.isSelectable = false

      collectionView.register(
        WebtoonPageCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier("WebtoonPageCell"))
      collectionView.register(
        WebtoonFooterCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier("WebtoonFooterCell"))

      let scrollView = NSScrollView()
      scrollView.documentView = collectionView
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true
      scrollView.backgroundColor = NSColor(readerBackground.color)
      scrollView.contentView.postsBoundsChangedNotifications = true

      let clickGesture = NSClickGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
      collectionView.addGestureRecognizer(clickGesture)

      context.coordinator.collectionView = collectionView
      context.coordinator.scrollView = scrollView
      context.coordinator.layout = layout
      context.coordinator.scheduleInitialScroll()
      context.coordinator.setupKeyboardMonitor()

      // Use boundsDidChangeNotification to detect all scrolling (including programmatic)
      NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(Coordinator.scrollViewDidScroll(_:)),
        name: NSView.boundsDidChangeNotification,
        object: scrollView.contentView)
      NotificationCenter.default.addObserver(
        context.coordinator,
        selector: #selector(Coordinator.scrollViewDidEndScroll(_:)),
        name: NSScrollView.didEndLiveScrollNotification,
        object: scrollView)

      return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
      scrollView.backgroundColor = NSColor(readerBackground.color)
      if let collectionView = scrollView.documentView as? NSCollectionView {
        collectionView.backgroundColors = [NSColor(readerBackground.color)]
        context.coordinator.update(
          pages: pages,
          viewModel: viewModel,
          onPageChange: onPageChange,
          onCenterTap: onCenterTap,
          onScrollToBottom: onScrollToBottom,
          pageWidth: pageWidth,
          collectionView: collectionView,
          readerBackground: readerBackground)
      }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    class Coordinator: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource,
      NSCollectionViewDelegateFlowLayout
    {
      var parent: WebtoonReaderView
      var collectionView: NSCollectionView?
      var scrollView: NSScrollView?
      var layout: WebtoonLayout?
      var pages: [BookPage] = []
      var currentPage: Int = 0
      weak var viewModel: ReaderViewModel?
      var onPageChange: ((Int) -> Void)?
      var onCenterTap: (() -> Void)?
      var onScrollToBottom: ((Bool) -> Void)?
      var lastPagesCount: Int = 0
      var isUserScrolling: Bool = false
      var hasScrolledToInitialPage: Bool = false
      var lastPreloadTime: Date?
      var pageWidth: CGFloat = 0
      var lastPageWidth: CGFloat = 0
      var isAtBottom: Bool = false
      var lastTargetPageIndex: Int?
      var readerBackground: ReaderBackground = .system
      var pageHeights: [Int: CGFloat] = [:]
      var keyMonitor: Any?

      init(_ parent: WebtoonReaderView) {
        self.parent = parent
        self.pages = parent.pages
        self.currentPage = parent.viewModel.currentPageIndex
        self.viewModel = parent.viewModel
        self.onPageChange = parent.onPageChange
        self.onCenterTap = parent.onCenterTap
        self.onScrollToBottom = parent.onScrollToBottom
        self.lastPagesCount = parent.pages.count
        self.pageWidth = parent.pageWidth
        self.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.readerBackground
      }

      deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = keyMonitor {
          NSEvent.removeMonitor(monitor)
        }
      }

      func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
          guard let self = self else { return event }
          return self.handleKeyDown(event) ? nil : event
        }
      }

      func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let sv = scrollView, let window = sv.window, window.isKeyWindow else { return false }
        let screenHeight = window.contentView?.bounds.height ?? window.frame.height

        switch event.keyCode {
        case 125:  // Down arrow
          scrollDown(screenHeight)
          return true
        case 126:  // Up arrow
          scrollUp(screenHeight)
          return true
        default:
          return false
        }
      }

      func isValidPageIndex(_ index: Int) -> Bool {
        index >= 0 && index < pages.count
      }

      func placeholderHeight(for index: Int) -> CGFloat {
        guard pageWidth > 0 else { return 0 }
        if let cached = pageHeights[index] { return cached }
        if index < pages.count,
          let w = pages[index].width, let h = pages[index].height, w > 0
        {
          let ratio = CGFloat(h) / CGFloat(w)
          if ratio.isFinite && ratio > 0 { return pageWidth * ratio }
        }
        return pageWidth * 3
      }

      func applyMetadataHeights() {
        guard pageWidth > 0 else { return }
        for (i, page) in pages.enumerated() {
          guard let w = page.width, let h = page.height, w > 0 else { continue }
          let ratio = CGFloat(h) / CGFloat(w)
          if ratio.isFinite && ratio > 0 && pageHeights[i] == nil {
            pageHeights[i] = pageWidth * ratio
          }
        }
      }

      func scheduleInitialScroll() {
        DispatchQueue.main.asyncAfter(deadline: .now() + WebtoonConstants.initialScrollDelay) {
          [weak self] in
          guard let self = self, !self.hasScrolledToInitialPage,
            self.pages.count > 0, self.isValidPageIndex(self.currentPage)
          else { return }
          self.scrollToInitialPage(self.currentPage)
        }
      }

      func calculateOffsetToPage(_ pageIndex: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<pageIndex {
          offset += pageHeights[i] ?? placeholderHeight(for: i)
        }
        return offset
      }

      func update(
        pages: [BookPage],
        viewModel: ReaderViewModel,
        onPageChange: ((Int) -> Void)?,
        onCenterTap: (() -> Void)?,
        onScrollToBottom: ((Bool) -> Void)?,
        pageWidth: CGFloat,
        collectionView: NSCollectionView,
        readerBackground: ReaderBackground
      ) {
        self.pages = pages
        self.viewModel = viewModel
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onScrollToBottom = onScrollToBottom
        self.pageWidth = pageWidth
        self.readerBackground = readerBackground
        applyMetadataHeights()

        let currentPage = viewModel.currentPageIndex

        if lastPagesCount != pages.count || abs(lastPageWidth - pageWidth) > 0.1 {
          if lastPagesCount != pages.count { pageHeights.removeAll() }
          applyMetadataHeights()
          lastPagesCount = pages.count
          lastPageWidth = pageWidth
          hasScrolledToInitialPage = false
          collectionView.reloadData()
        }

        for ip in collectionView.indexPathsForVisibleItems() {
          if ip.item < pages.count,
            let cell = collectionView.item(at: ip) as? WebtoonPageCell
          {
            cell.readerBackground = readerBackground
          } else if let cell = collectionView.item(at: ip) as? WebtoonFooterCell {
            cell.readerBackground = readerBackground
          }
        }

        if !hasScrolledToInitialPage && pages.count > 0 && isValidPageIndex(currentPage) {
          scrollToInitialPage(currentPage)
        }

        if let target = viewModel.targetPageIndex,
          target != lastTargetPageIndex, isValidPageIndex(target)
        {
          lastTargetPageIndex = target
          scrollToPage(target, animated: true)
          viewModel.targetPageIndex = nil
          if self.currentPage != target {
            self.currentPage = target
            onPageChange?(target)
          }
        } else if self.currentPage != currentPage {
          self.currentPage = currentPage
        }
      }

      func scrollToPage(_ pageIndex: Int, animated: Bool) {
        guard let cv = collectionView, isValidPageIndex(pageIndex) else { return }
        let ip = IndexPath(item: pageIndex, section: 0)
        if let attr = cv.layoutAttributesForItem(at: ip) {
          if animated {
            NSAnimationContext.runAnimationGroup {
              $0.duration = 0.3
              cv.animator().scroll(attr.frame.origin)
            }
          } else {
            cv.scroll(attr.frame.origin)
          }
        }
      }

      func scrollToInitialPage(_ pageIndex: Int) {
        guard !hasScrolledToInitialPage,
          let cv = collectionView, isValidPageIndex(pageIndex),
          cv.bounds.width > 0
        else {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToInitialPage(pageIndex)
          }
          return
        }
        let ip = IndexPath(item: pageIndex, section: 0)
        if let attr = cv.layoutAttributesForItem(at: ip) {
          cv.scroll(attr.frame.origin)
        }
        hasScrolledToInitialPage = true
      }

      // MARK: - DataSource

      func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int)
        -> Int
      { pages.count + 1 }

      func collectionView(
        _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath
      ) -> NSCollectionViewItem {
        if indexPath.item == pages.count {
          let cell =
            collectionView.makeItem(
              withIdentifier: NSUserInterfaceItemIdentifier("WebtoonFooterCell"),
              for: indexPath) as! WebtoonFooterCell
          cell.readerBackground = readerBackground
          return cell
        }

        let cell =
          collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("WebtoonPageCell"),
            for: indexPath) as! WebtoonPageCell
        cell.readerBackground = readerBackground
        let pageIndex = indexPath.item

        cell.configure(pageIndex: pageIndex, image: nil) { [weak self] idx in
          Task { @MainActor in await self?.loadImageForPage(idx) }
        }

        Task { @MainActor [weak self] in
          await self?.loadImageForPage(pageIndex)
        }

        return cell
      }

      func collectionView(
        _ collectionView: NSCollectionView, layout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> NSSize {
        if indexPath.item == pages.count {
          return NSSize(width: pageWidth, height: WebtoonConstants.footerHeight)
        }
        return NSSize(width: pageWidth, height: placeholderHeight(for: indexPath.item))
      }

      // MARK: - Scroll

      @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let sv = scrollView else { return }
        isUserScrolling = true
        checkIfAtBottom(sv)
        updateCurrentPage()
        throttlePreload()
      }

      @objc func scrollViewDidEndScroll(_ notification: Notification) {
        guard let sv = scrollView else { return }
        isUserScrolling = false
        checkIfAtBottom(sv)
        updateCurrentPage()
        preloadNearbyPages()
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

      private func checkIfAtBottom(_ scrollView: NSScrollView) {
        guard hasScrolledToInitialPage, let cv = collectionView else { return }
        let contentHeight = cv.collectionViewLayout?.collectionViewContentSize.height ?? 0
        let offset = scrollView.contentView.bounds.origin.y
        let viewHeight = scrollView.contentView.bounds.height
        guard contentHeight > viewHeight else { return }

        let atBottom = offset + viewHeight >= contentHeight - WebtoonConstants.bottomThreshold
        if atBottom != isAtBottom {
          isAtBottom = atBottom
          onScrollToBottom?(atBottom)
        }
      }

      private func updateCurrentPage() {
        guard let cv = collectionView, let sv = scrollView else { return }
        let centerY = sv.contentView.bounds.origin.y + sv.contentView.bounds.height / 2
        let centerPt = NSPoint(x: cv.bounds.width / 2, y: centerY)
        if let ip = cv.indexPathForItem(at: centerPt),
          ip.item < pages.count, ip.item != currentPage
        {
          currentPage = ip.item
          onPageChange?(ip.item)
        }
      }

      // MARK: - Image Loading

      @MainActor
      func loadImageForPage(_ pageIndex: Int) async {
        guard isValidPageIndex(pageIndex), let vm = viewModel else { return }
        let page = pages[pageIndex]
        guard let url = await vm.getPageImageFileURL(page: page) else { return }

        if let cv = collectionView,
          let cell = cv.item(at: IndexPath(item: pageIndex, section: 0)) as? WebtoonPageCell
        {
          cell.setImageURL(url, imageSize: nil)
        }

        if let size = await getImageSize(from: url) {
          let h = pageWidth * size.height / size.width
          let old = pageHeights[pageIndex] ?? pageWidth
          pageHeights[pageIndex] = h
          if abs(h - old) > 1 {
            layout?.invalidateLayout()
          }
        }
      }

      private func getImageSize(from url: URL) async -> CGSize? {
        if let key = SDImageCacheProvider.pageImageManager.cacheKey(for: url),
          let img = SDImageCacheProvider.pageImageCache.imageFromCache(forKey: key)
        {
          if let rep = img.representations.first {
            return CGSize(width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh))
          }
          return img.size
        }
        return await Task.detached {
          guard url.isFileURL,
            let data = try? Data(contentsOf: url),
            let src = CGImageSourceCreateWithData(data as CFData, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any],
            let w = props[kCGImagePropertyPixelWidth as String] as? CGFloat,
            let h = props[kCGImagePropertyPixelHeight as String] as? CGFloat
          else { return nil }
          return CGSize(width: w, height: h)
        }.value
      }

      func preloadNearbyPages() {
        guard let cv = collectionView else { return }
        let visible = cv.indexPathsForVisibleItems()
        guard !visible.isEmpty else { return }
        let indices = visible.map { $0.item }
        let minV = indices.min() ?? 0
        let maxV = indices.max() ?? pages.count - 1

        Task { @MainActor [weak self] in
          guard let self = self, let vm = self.viewModel else { return }
          for i in max(0, minV - 2)...min(self.pages.count - 1, maxV + 2) {
            let page = self.pages[i]
            if !(await vm.pageImageCache.hasImage(bookId: vm.bookId, page: page)) {
              await self.loadImageForPage(i)
            }
          }
        }
      }

      // MARK: - Click

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let sv = scrollView, let window = sv.window else { return }

        // Get location in window coordinates (origin at bottom-left)
        let locInWindow = gesture.location(in: nil)
        // Convert to flipped coordinates (origin at top-left, like iOS)
        let windowHeight = window.contentView?.bounds.height ?? window.frame.height
        let loc = NSPoint(x: locInWindow.x, y: windowHeight - locInWindow.y)

        let h = windowHeight
        let w = window.contentView?.bounds.width ?? window.frame.width

        // Now using flipped coordinates (origin at top-left)
        // Top area: small y values
        // Bottom area: large y values
        let isTopArea = loc.y < h * WebtoonConstants.topAreaThreshold
        let isBottomArea = loc.y > h * WebtoonConstants.bottomAreaThreshold
        let isMiddleY = !isTopArea && !isBottomArea
        let isLeftArea = loc.x < w * WebtoonConstants.topAreaThreshold

        let isCenterArea =
          loc.x > w * WebtoonConstants.centerAreaMin
          && loc.x < w * WebtoonConstants.centerAreaMax
          && loc.y > h * WebtoonConstants.centerAreaMin
          && loc.y < h * WebtoonConstants.centerAreaMax

        if isCenterArea {
          onCenterTap?()
        } else if isTopArea || (isMiddleY && isLeftArea) {
          scrollUp(h)
        } else {
          scrollDown(h)
        }
      }

      private func scrollUp(_ screenHeight: CGFloat) {
        guard let sv = scrollView else { return }
        let clipView = sv.contentView
        let currentOrigin = clipView.bounds.origin
        let scrollAmount = screenHeight * WebtoonConstants.scrollAmountMultiplier
        let targetY = max(currentOrigin.y - scrollAmount, 0)

        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          clipView.animator().setBoundsOrigin(NSPoint(x: 0, y: targetY))
        }
        sv.reflectScrolledClipView(clipView)
      }

      private func scrollDown(_ screenHeight: CGFloat) {
        guard let sv = scrollView, let cv = collectionView else { return }
        let clipView = sv.contentView
        let currentOrigin = clipView.bounds.origin
        let contentH = cv.collectionViewLayout?.collectionViewContentSize.height ?? 0
        let scrollAmount = screenHeight * WebtoonConstants.scrollAmountMultiplier
        let maxY = max(contentH - screenHeight, 0)
        let targetY = min(currentOrigin.y + scrollAmount, maxY)

        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          clipView.animator().setBoundsOrigin(NSPoint(x: 0, y: targetY))
        }
        sv.reflectScrolledClipView(clipView)
      }
    }
  }
#endif
