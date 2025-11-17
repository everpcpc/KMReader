//
//  WebtoonReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import ImageIO
import SDWebImage
import SwiftUI

// MARK: - Constants
private enum Constants {
  static let initialScrollDelay: TimeInterval = 0.3
  static let layoutReadyDelay: TimeInterval = 0.2
  static let scrollRestoreDelay: TimeInterval = 0.3
  static let centerTapHandlingDelay: TimeInterval = 0.2
  static let preloadThrottleInterval: TimeInterval = 0.3
  static let scrollPositionThreshold: CGFloat = 50
  static let heightChangeThreshold: CGFloat = 100
  static let bottomThreshold: CGFloat = 80
  static let footerHeight: CGFloat = 360
  static let estimatedAspectRatio: CGFloat = 1.5
  static let scrollAmountMultiplier: CGFloat = 0.8
  static let topAreaThreshold: CGFloat = 0.3
  static let bottomAreaThreshold: CGFloat = 0.7
  static let centerAreaMin: CGFloat = 0.3
  static let centerAreaMax: CGFloat = 0.7
}

struct WebtoonReaderView: UIViewRepresentable {
  let pages: [BookPage]
  @Binding var currentPage: Int
  let viewModel: ReaderViewModel
  let onPageChange: ((Int) -> Void)?
  let onCenterTap: (() -> Void)?
  let onScrollToBottom: ((Bool) -> Void)?
  let pageWidth: CGFloat

  init(
    pages: [BookPage], currentPage: Binding<Int>, viewModel: ReaderViewModel,
    pageWidth: CGFloat,
    onPageChange: ((Int) -> Void)? = nil,
    onCenterTap: (() -> Void)? = nil,
    onScrollToBottom: ((Bool) -> Void)? = nil
  ) {
    self.pages = pages
    self._currentPage = currentPage
    self.viewModel = viewModel
    self.pageWidth = pageWidth
    self.onPageChange = onPageChange
    self.onCenterTap = onCenterTap
    self.onScrollToBottom = onScrollToBottom
  }

  func makeUIView(context: Context) -> UICollectionView {
    let layout = WebtoonLayout()
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.delegate = context.coordinator
    collectionView.dataSource = context.coordinator
    collectionView.backgroundColor = .black
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.bounces = false
    collectionView.scrollsToTop = false
    collectionView.isPrefetchingEnabled = true

    // Register cell
    collectionView.register(WebtoonPageCell.self, forCellWithReuseIdentifier: "WebtoonPageCell")
    collectionView.register(WebtoonFooterCell.self, forCellWithReuseIdentifier: "WebtoonFooterCell")

    // Add tap gesture recognizer for navigation
    let tapGesture = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    tapGesture.numberOfTapsRequired = 1
    collectionView.addGestureRecognizer(tapGesture)

    context.coordinator.collectionView = collectionView
    context.coordinator.layout = layout

    // Set up initial scroll after view appears
    context.coordinator.scheduleInitialScroll()

    return collectionView
  }

  func updateUIView(_ collectionView: UICollectionView, context: Context) {
    context.coordinator.update(
      pages: pages,
      currentPage: currentPage,
      viewModel: viewModel,
      onPageChange: onPageChange,
      onCenterTap: onCenterTap,
      onScrollToBottom: onScrollToBottom,
      pageWidth: pageWidth,
      collectionView: collectionView
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
    var lastExternalCurrentPage: Int = -1
    var isUserScrolling: Bool = false
    var hasScrolledToInitialPage: Bool = false
    var lastPreloadTime: Date?
    var pageWidth: CGFloat = 0
    var lastPageWidth: CGFloat = 0
    var isAtBottom: Bool = false
    var isHandlingCenterTap: Bool = false
    var savedScrollOffset: CGFloat = 0

    // Cache for page heights (images are cached in viewModel)
    var pageHeights: [Int: CGFloat] = [:]
    var loadingPages: Set<Int> = []

    init(_ parent: WebtoonReaderView) {
      self.parent = parent
      self.pages = parent.pages
      self.currentPage = parent.currentPage
      self.lastExternalCurrentPage = parent.currentPage
      self.viewModel = parent.viewModel
      self.onPageChange = parent.onPageChange
      self.onCenterTap = parent.onCenterTap
      self.onScrollToBottom = parent.onScrollToBottom
      self.lastPagesCount = parent.pages.count
      self.hasScrolledToInitialPage = false
      self.pageWidth = parent.pageWidth
      self.lastPageWidth = parent.pageWidth
    }

    // MARK: - Helper Methods

    /// Validates if a page index is within valid range
    func isValidPageIndex(_ index: Int) -> Bool {
      index >= 0 && index < pages.count
    }

    /// Calculates estimated height for a page
    func estimatedPageHeight() -> CGFloat {
      pageWidth * Constants.estimatedAspectRatio
    }

    /// Schedules initial scroll after view appears
    func scheduleInitialScroll() {
      DispatchQueue.main.asyncAfter(deadline: .now() + Constants.initialScrollDelay) {
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
          offset += estimatedPageHeight()
        }
      }
      return offset
    }

    /// Updates coordinator state and handles view updates
    func update(
      pages: [BookPage],
      currentPage: Int,
      viewModel: ReaderViewModel,
      onPageChange: ((Int) -> Void)?,
      onCenterTap: (() -> Void)?,
      onScrollToBottom: ((Bool) -> Void)?,
      pageWidth: CGFloat,
      collectionView: UICollectionView
    ) {
      self.pages = pages
      self.currentPage = currentPage
      self.viewModel = viewModel
      self.onPageChange = onPageChange
      self.onCenterTap = onCenterTap
      self.onScrollToBottom = onScrollToBottom
      self.pageWidth = pageWidth

      // Handle data reload if needed
      if lastPagesCount != pages.count || abs(lastPageWidth - pageWidth) > 0.1 {
        handleDataReload(collectionView: collectionView, currentPage: currentPage)

        // Update pageWidth for all visible cells when pageWidth changes
        if abs(lastPageWidth - pageWidth) > 0.1 {
          updateVisibleCellsPageWidth(collectionView: collectionView)
        }
      }

      // Handle center tap state
      if isHandlingCenterTap {
        handleCenterTapState(currentPage: currentPage)
        return
      }

      // Handle initial scroll if needed
      if !hasScrolledToInitialPage && pages.count > 0 && isValidPageIndex(currentPage) {
        scrollToInitialPage(currentPage)
      }
    }

    /// Updates pageWidth for all visible cells
    private func updateVisibleCellsPageWidth(collectionView: UICollectionView) {
      let visibleIndexPaths = collectionView.indexPathsForVisibleItems
      for indexPath in visibleIndexPaths {
        if indexPath.item < pages.count,
          let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell
        {
          cell.setPageWidth(pageWidth)
        }
      }
    }

    /// Handles data reload when pages count or width changes
    private func handleDataReload(collectionView: UICollectionView, currentPage: Int) {
      lastPagesCount = pages.count
      lastPageWidth = pageWidth
      hasScrolledToInitialPage = false
      collectionView.reloadData()
      collectionView.layoutIfNeeded()

      if isValidPageIndex(currentPage) {
        executeAfterDelay(Constants.layoutReadyDelay) { [weak self] in
          self?.scrollToInitialPage(currentPage)
        }
        executeAfterDelay(0.5) { [weak self] in
          guard let self = self, !self.hasScrolledToInitialPage else { return }
          self.scrollToInitialPage(currentPage)
        }
      }
    }

    /// Handles center tap state to preserve scroll position
    private func handleCenterTapState(currentPage: Int) {
      if savedScrollOffset > 0, let collectionView = collectionView {
        let currentOffset = collectionView.contentOffset.y
        if abs(currentOffset - savedScrollOffset) > Constants.scrollPositionThreshold {
          collectionView.setContentOffset(
            CGPoint(x: 0, y: savedScrollOffset),
            animated: false
          )
        }
      }
      lastExternalCurrentPage = currentPage
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
          executeAfterDelay(Constants.layoutReadyDelay) { [weak self] in
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
        self.lastExternalCurrentPage = pageIndex
      }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
      -> Int
    {
      // Add 1 for footer cell
      pages.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
      -> UICollectionViewCell
    {
      // Check if this is the footer cell (last item)
      if indexPath.item == pages.count {
        let cell =
          collectionView.dequeueReusableCell(
            withReuseIdentifier: "WebtoonFooterCell", for: indexPath)
          as! WebtoonFooterCell
        return cell
      }

      let cell =
        collectionView.dequeueReusableCell(withReuseIdentifier: "WebtoonPageCell", for: indexPath)
        as! WebtoonPageCell

      let pageIndex = indexPath.item

      // Load image asynchronously (loadImageForPage handles both cached and uncached images)
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

      // Ensure cell knows about pageWidth immediately
      // This helps when cell is reused and needs to update its frame
      cell.setPageWidth(pageWidth)

      return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(
      _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
      sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
      // Footer cell - fixed height for button area
      if indexPath.item == pages.count {
        return CGSize(width: pageWidth, height: Constants.footerHeight)
      }

      if let height = pageHeights[indexPath.item] {
        return CGSize(width: pageWidth, height: height)
      }

      // Default height (will be updated when image loads)
      return CGSize(width: pageWidth, height: pageWidth)
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(
      _ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
      forItemAt indexPath: IndexPath
    ) {
      // Ensure cell has correct pageWidth when displayed
      if let webtoonCell = cell as? WebtoonPageCell {
        // Set pageWidth to ensure image view uses correct width
        webtoonCell.setPageWidth(pageWidth)
      }
    }

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
        || now.timeIntervalSince(lastPreloadTime!) > Constants.preloadThrottleInterval
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
      // Don't check if at bottom until initial scroll is complete
      // This prevents showing end page when view first opens
      guard hasScrolledToInitialPage else {
        return
      }

      let contentHeight = scrollView.contentSize.height
      let scrollOffset = scrollView.contentOffset.y
      let scrollViewHeight = scrollView.bounds.height

      // Also check that content size is valid (not zero or too small)
      guard contentHeight > scrollViewHeight else {
        return
      }

      let isAtBottomNow =
        scrollOffset + scrollViewHeight >= contentHeight - Constants.bottomThreshold

      if isAtBottomNow != isAtBottom {
        isAtBottom = isAtBottomNow
        onScrollToBottom?(isAtBottom)
      }
    }

    private func updateCurrentPage() {
      guard let collectionView = collectionView else { return }

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
        // Fallback: find closest page by checking visible items
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
          .filter { $0.item < pages.count }
          .sorted { $0.item < $1.item }
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

      // Get file URL (downloads to cache if needed)
      guard let imageURL = await viewModel.getPageImageFileURL(pageIndex: pageIndex) else {
        showImageError(for: pageIndex)
        return
      }

      // Check if already cached
      let isFromCache = viewModel.pageImageCache.hasImage(
        forKey: pageIndex, bookId: viewModel.bookId)

      // Get image size for layout calculation (without fully loading)
      let imageSize = await getImageSize(from: imageURL)

      // Update cell with URL and size
      if let collectionView = collectionView {
        let indexPath = IndexPath(item: pageIndex, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
          cell.setImageURL(imageURL, imageSize: imageSize, pageWidth: pageWidth)
        }
      }

      // Calculate and cache height
      if let size = imageSize {
        let aspectRatio = size.height / size.width
        let height = pageWidth * aspectRatio
        let oldHeight = pageHeights[pageIndex] ?? pageWidth
        pageHeights[pageIndex] = height

        // Update layout if height changed
        updateLayoutIfNeeded(pageIndex: pageIndex, height: height, oldHeight: oldHeight)

        // Ensure cell has correct pageWidth after layout update
        if let collectionView = collectionView {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
            cell.setPageWidth(pageWidth)
          }
        }

        // Try to scroll to initial page if needed (only for newly loaded images)
        if !isFromCache {
          tryScrollToInitialPageIfNeeded(pageIndex: pageIndex)
        }
      }
    }

    /// Get image size from URL without fully loading the image
    private func getImageSize(from url: URL) async -> CGSize? {
      return await Task.detached {
        // Try to get from SDWebImage cache first
        let cacheKey = SDWebImageManager.shared.cacheKey(for: url)
        if let cachedImage = SDImageCache.shared.imageFromCache(forKey: cacheKey) {
          return cachedImage.size
        }

        // If not in SDWebImage cache, try to read from file
        if url.isFileURL {
          // Use ImageIO to get image dimensions without decoding
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
          // For visible cells, always invalidate layout to ensure correct sizing
          layout.invalidateLayout()
          collectionView.layoutIfNeeded()

          // Force cell to update its frame after layout
          if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
            DispatchQueue.main.async {
              cell.setNeedsLayout()
              cell.layoutIfNeeded()
              cell.updateFrame()
            }
          }
        } else if heightDiff > Constants.heightChangeThreshold {
          // For non-visible cells, only update if height changed significantly
          if !isUserScrolling {
            let currentOffset = collectionView.contentOffset.y
            layout.invalidateLayout()
            collectionView.layoutIfNeeded()

            if pageIndex < currentPage {
              let newOffset = max(0, currentOffset + (height - oldHeight))
              UIView.performWithoutAnimation {
                collectionView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
              }
            }
          } else {
            // During scrolling, update layout after a short delay
            executeAfterDelay(0.3) { [weak self] in
              guard let self = self, !self.isUserScrolling,
                let collectionView = self.collectionView,
                let layout = self.layout
              else { return }
              let currentHeight = self.pageHeights[pageIndex] ?? 0
              if abs(currentHeight - oldHeight) > Constants.heightChangeThreshold {
                layout.invalidateLayout()
                collectionView.layoutIfNeeded()
              }
            }
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

    // Preload nearby pages
    func preloadNearbyPages() {
      guard let collectionView = collectionView else { return }

      let visibleIndexPaths = collectionView.indexPathsForVisibleItems
      guard !visibleIndexPaths.isEmpty else { return }

      let visibleIndices = Set(visibleIndexPaths.map { $0.item })

      // Preload 3 pages before and after visible range
      let minVisible = visibleIndices.min() ?? 0
      let maxVisible = visibleIndices.max() ?? pages.count - 1

      // Preload nearby pages (reduced from 3 to 2 to save memory)
      // Access viewModel in MainActor context to ensure thread safety
      Task { @MainActor [weak self] in
        guard let self = self,
          let viewModel = self.viewModel
        else { return }

        for i in max(0, minVisible - 2)...min(self.pages.count - 1, maxVisible + 2) {
          if !viewModel.pageImageCache.hasImage(forKey: i, bookId: viewModel.bookId) {
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
      let isTopArea = location.y < screenHeight * Constants.topAreaThreshold
      let isBottomArea = location.y > screenHeight * Constants.bottomAreaThreshold
      let isMiddleArea = !isTopArea && !isBottomArea
      let isLeftArea = location.x < screenWidth * Constants.topAreaThreshold

      let isCenterArea =
        location.x > screenWidth * Constants.centerAreaMin
        && location.x < screenWidth * Constants.centerAreaMax
        && location.y > screenHeight * Constants.centerAreaMin
        && location.y < screenHeight * Constants.centerAreaMax

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
      isHandlingCenterTap = true
      savedScrollOffset = collectionView.contentOffset.y
      onCenterTap?()

      executeAfterDelay(Constants.centerTapHandlingDelay) { [weak self] in
        self?.isHandlingCenterTap = false
      }
    }

    /// Scrolls up
    private func scrollUp(collectionView: UICollectionView, screenHeight: CGFloat) {
      let currentOffset = collectionView.contentOffset.y
      let scrollAmount = screenHeight * Constants.scrollAmountMultiplier
      let targetOffset = max(currentOffset - scrollAmount, 0)
      collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
    }

    /// Scrolls down
    private func scrollDown(collectionView: UICollectionView, screenHeight: CGFloat) {
      let currentOffset = collectionView.contentOffset.y
      let scrollAmount = screenHeight * Constants.scrollAmountMultiplier
      let targetOffset = min(
        currentOffset + scrollAmount,
        collectionView.contentSize.height - screenHeight
      )
      collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
    }
  }
}

// MARK: - Custom Layout

class WebtoonLayout: UICollectionViewFlowLayout {
  override func prepare() {
    super.prepare()
    scrollDirection = .vertical
    minimumLineSpacing = 0
    minimumInteritemSpacing = 0
    sectionInset = .zero
  }
}

// MARK: - Custom Cell

class WebtoonPageCell: UICollectionViewCell {
  private let imageView = SDAnimatedImageView()
  private let loadingIndicator = UIActivityIndicatorView(style: .medium)
  private var pageIndex: Int = -1
  private var loadImage: ((Int) async -> Void)?
  private var pageWidth: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    contentView.backgroundColor = .black

    // Use scaleAspectFit to maintain aspect ratio while filling width
    // The cell height is calculated based on image aspect ratio, so this should work
    imageView.contentMode = .scaleAspectFit
    imageView.backgroundColor = .black
    imageView.clipsToBounds = false  // Don't clip, let image fill the space
    // Use frame-based layout - will be set in layoutSubviews
    contentView.addSubview(imageView)

    loadingIndicator.color = .white
    loadingIndicator.hidesWhenStopped = true
    contentView.addSubview(loadingIndicator)
  }

  func configure(
    pageIndex: Int, image: UIImage?, loadImage: @escaping (Int) async -> Void
  ) {
    self.pageIndex = pageIndex
    self.loadImage = loadImage

    // Ensure frame is set correctly
    updateFrame()

    // Show loading indicator
    imageView.image = nil
    imageView.alpha = 0.0
    loadingIndicator.startAnimating()
  }

  func setPageWidth(_ width: CGFloat) {
    if abs(pageWidth - width) > 0.1 {
      pageWidth = width
      updateFrame()
    }
  }

  func setImageURL(_ url: URL, imageSize: CGSize?, pageWidth: CGFloat) {
    // Save pageWidth to ensure image view uses correct width
    self.pageWidth = pageWidth

    // Stop loading indicator
    loadingIndicator.stopAnimating()

    // Update frame immediately with correct pageWidth
    updateFrame()

    // Load image using SDWebImage
    imageView.sd_setImage(
      with: url,
      placeholderImage: nil,
      options: [.retryFailed, .scaleDownLargeImages],
      context: [
        .imageScaleDownLimitBytes: 50 * 1024 * 1024
      ],
      progress: nil
    ) { [weak self] image, error, cacheType, imageURL in
      guard let self = self else { return }

      if error != nil {
        // Handle error
        self.imageView.image = nil
        self.imageView.alpha = 0.0
        self.loadingIndicator.stopAnimating()
      } else if image != nil {
        // Image loaded successfully
        self.loadingIndicator.stopAnimating()

        // Force layout update to ensure frame is correct
        self.updateFrame()
        self.setNeedsLayout()
        self.layoutIfNeeded()

        UIView.animate(withDuration: 0.2) {
          self.imageView.alpha = 1.0
        }
      }
    }
  }

  func updateFrame() {
    // Ensure image view frame matches content view bounds
    // This is critical for webtoon reading where images must fill the width
    let bounds = contentView.bounds
    let cellBounds = self.bounds

    // Use pageWidth if available and valid, otherwise use bounds width
    let targetWidth: CGFloat
    if pageWidth > 0 {
      targetWidth = pageWidth
    } else if bounds.width > 0 {
      targetWidth = bounds.width
    } else if cellBounds.width > 0 {
      targetWidth = cellBounds.width
    } else {
      return
    }

    // Use bounds height if available, otherwise use cell bounds height
    let targetHeight: CGFloat
    if bounds.height > 0 {
      targetHeight = bounds.height
    } else if cellBounds.height > 0 {
      targetHeight = cellBounds.height
    } else {
      return
    }

    imageView.frame = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
    loadingIndicator.center = CGPoint(x: targetWidth / 2, y: targetHeight / 2)
  }

  func showError() {
    imageView.image = nil
    imageView.alpha = 0.0
    loadingIndicator.stopAnimating()
    // Could show an error indicator here if needed
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Directly set frame to ensure image view fills the entire cell
    updateFrame()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    // Cancel SDWebImage loading
    imageView.sd_cancelCurrentImageLoad()
    imageView.image = nil
    imageView.alpha = 0.0
    loadingIndicator.stopAnimating()
    loadingIndicator.isHidden = true
    pageIndex = -1
    loadImage = nil
  }
}

// MARK: - Footer Cell

class WebtoonFooterCell: UICollectionViewCell {
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    contentView.backgroundColor = .black
  }
}
