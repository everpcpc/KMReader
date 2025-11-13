//
//  WebtoonReaderView.swift
//  Komga
//
//  Created based on Aidoku's ReaderWebtoonViewController implementation
//

import SwiftUI
import UIKit

// Wrapper class to avoid closure capture issues
@MainActor
class ImageLoader: @unchecked Sendable {
  weak var viewModel: ReaderViewModel?

  init(viewModel: ReaderViewModel) {
    self.viewModel = viewModel
  }

  func loadImage(_ pageIndex: Int) async -> UIImage? {
    guard let viewModel = viewModel else {
      return nil
    }
    return await viewModel.loadPageImage(pageIndex: pageIndex)
  }
}

struct WebtoonReaderView: UIViewRepresentable {
  let pages: [BookPage]
  @Binding var currentPage: Int
  let imageLoader: ImageLoader
  let onPageChange: ((Int) -> Void)?
  let onCenterTap: (() -> Void)?
  let onScrollToBottom: ((Bool) -> Void)?
  @AppStorage("webtoonPageWidthPercentage") private var pageWidthPercentage: Double = 100.0

  init(
    pages: [BookPage], currentPage: Binding<Int>, viewModel: ReaderViewModel,
    onPageChange: ((Int) -> Void)? = nil,
    onCenterTap: (() -> Void)? = nil,
    onScrollToBottom: ((Bool) -> Void)? = nil
  ) {
    self.pages = pages
    self._currentPage = currentPage
    self.imageLoader = ImageLoader(viewModel: viewModel)
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      if !context.coordinator.hasScrolledToInitialPage
        && context.coordinator.pages.count > 0
        && context.coordinator.currentPage >= 0
        && context.coordinator.currentPage < context.coordinator.pages.count
      {
        context.coordinator.scrollToInitialPage(context.coordinator.currentPage)
      }
    }

    return collectionView
  }

  func updateUIView(_ collectionView: UICollectionView, context: Context) {
    context.coordinator.pages = pages
    context.coordinator.currentPage = currentPage
    context.coordinator.imageLoader = imageLoader
    context.coordinator.onPageChange = onPageChange
    context.coordinator.onCenterTap = onCenterTap
    context.coordinator.onScrollToBottom = onScrollToBottom
    context.coordinator.pageWidthPercentage = pageWidthPercentage

    // Reload data if pages count changed or width percentage changed
    if context.coordinator.lastPagesCount != pages.count
      || context.coordinator.lastPageWidthPercentage != pageWidthPercentage
    {
      context.coordinator.lastPagesCount = pages.count
      context.coordinator.lastPageWidthPercentage = pageWidthPercentage
      context.coordinator.hasScrolledToInitialPage = false
      collectionView.reloadData()

      // Force layout
      collectionView.layoutIfNeeded()

      // Scroll to current page after reload - wait for layout
      if currentPage >= 0 && currentPage < pages.count {
        // Try multiple times with increasing delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          context.coordinator.scrollToInitialPage(currentPage)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          if !context.coordinator.hasScrolledToInitialPage {
            context.coordinator.scrollToInitialPage(currentPage)
          }
        }
      }
    }

    // If pages are loaded but we haven't scrolled to initial page yet
    if !context.coordinator.hasScrolledToInitialPage
      && pages.count > 0
      && currentPage >= 0
      && currentPage < pages.count
    {
      // Try to scroll, will retry if layout not ready
      context.coordinator.scrollToInitialPage(currentPage)
    }

    // Scroll to current page if changed externally
    let currentPageChangedExternally = currentPage != context.coordinator.lastExternalCurrentPage
    if currentPageChangedExternally && currentPage >= 0 && currentPage < pages.count
      && !context.coordinator.isUserScrolling
      && !context.coordinator.isProgrammaticScrolling
    {
      context.coordinator.scrollToPage(currentPage, animated: true)
      context.coordinator.lastExternalCurrentPage = currentPage
    } else if !currentPageChangedExternally {
      context.coordinator.lastExternalCurrentPage = currentPage
    }
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
    var imageLoader: ImageLoader?
    var onPageChange: ((Int) -> Void)?
    var onCenterTap: (() -> Void)?
    var onScrollToBottom: ((Bool) -> Void)?
    var lastPagesCount: Int = 0
    var lastExternalCurrentPage: Int = -1
    var isUserScrolling: Bool = false
    var isProgrammaticScrolling: Bool = false
    var hasScrolledToInitialPage: Bool = false
    var lastPreloadTime: Date?
    var pageWidthPercentage: Double = 100.0
    var lastPageWidthPercentage: Double = 100.0
    var isAtBottom: Bool = false

    // Cache for page heights and images
    var pageHeights: [Int: CGFloat] = [:]
    var pageImages: [Int: UIImage] = [:]
    var loadingPages: Set<Int> = []

    init(_ parent: WebtoonReaderView) {
      self.parent = parent
      self.pages = parent.pages
      self.currentPage = parent.currentPage
      self.lastExternalCurrentPage = parent.currentPage
      self.imageLoader = parent.imageLoader
      self.onPageChange = parent.onPageChange
      self.onCenterTap = parent.onCenterTap
      self.onScrollToBottom = parent.onScrollToBottom
      self.lastPagesCount = parent.pages.count
      self.hasScrolledToInitialPage = false
      self.pageWidthPercentage = parent.pageWidthPercentage
      self.lastPageWidthPercentage = parent.pageWidthPercentage
    }

    func scrollToPage(_ pageIndex: Int, animated: Bool) {
      guard let collectionView = collectionView,
        pageIndex >= 0 && pageIndex < pages.count
      else { return }

      // Use scrollToItem for more reliable scrolling
      let indexPath = IndexPath(item: pageIndex, section: 0)

      // If layout is ready, scroll directly
      if collectionView.contentSize.height > 0 {
        collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
      } else {
        // Wait for layout, then scroll
        DispatchQueue.main.async { [weak self] in
          guard let self = self, let collectionView = self.collectionView else { return }
          if collectionView.contentSize.height > 0 {
            collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
          } else {
            // Fallback: calculate offset manually
            var offset: CGFloat = 0
            for i in 0..<pageIndex {
              if let height = self.pageHeights[i] {
                offset += height
              } else {
                let screenWidth = collectionView.bounds.width
                let width = screenWidth * (self.pageWidthPercentage / 100.0)
                offset += width * 1.5
              }
            }
            collectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
          }
        }
      }
    }

    func scrollToInitialPage(_ pageIndex: Int) {
      guard !hasScrolledToInitialPage else { return }
      guard let collectionView = collectionView,
        pageIndex >= 0 && pageIndex < pages.count,
        collectionView.bounds.width > 0 && collectionView.bounds.height > 0
      else {
        // Retry if conditions not met (only once)
        if !hasScrolledToInitialPage {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToInitialPage(pageIndex)
          }
        }
        return
      }

      // Don't scroll if user is currently scrolling
      guard !isUserScrolling else {
        // Wait for scrolling to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
          guard let self = self, !self.hasScrolledToInitialPage else { return }
          self.scrollToInitialPage(pageIndex)
        }
        return
      }

      // Force layout update
      collectionView.layoutIfNeeded()

      // Wait for layout to be ready
      guard collectionView.contentSize.height > 0 else {
        // Retry after a short delay if layout not ready (only once)
        if !hasScrolledToInitialPage {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToInitialPage(pageIndex)
          }
        }
        return
      }

      // Calculate offset based on cached heights
      var offset: CGFloat = 0

      for i in 0..<pageIndex {
        if let height = pageHeights[i] {
          offset += height
        } else {
          // If we don't have the height yet, use estimated height
          let screenWidth = collectionView.bounds.width
          let width = screenWidth * (pageWidthPercentage / 100.0)
          offset += width * 1.5
        }
      }

      // Use scrollToItem for reliable scrolling
      let indexPath = IndexPath(item: pageIndex, section: 0)

      collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
      collectionView.layoutIfNeeded()

      // Mark as scrolled after a brief delay to ensure scroll completed
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

      if pageImages[pageIndex] == nil {
        Task { @MainActor [weak self] in
          guard let self = self else { return }
          await self.loadImageForPage(pageIndex)
        }
      }

      cell.configure(
        pageIndex: pageIndex,
        image: pageImages[pageIndex],
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
      let screenWidth = collectionView.bounds.width
      let width = screenWidth * (pageWidthPercentage / 100.0)

      // Footer cell - fixed height for button area
      if indexPath.item == pages.count {
        return CGSize(width: width, height: 320)
      }

      if let height = pageHeights[indexPath.item] {
        return CGSize(width: width, height: height)
      }

      // If we have the image, calculate height from aspect ratio
      if let image = pageImages[indexPath.item] {
        let aspectRatio = image.size.height / image.size.width
        let height = width * aspectRatio
        pageHeights[indexPath.item] = height
        return CGSize(width: width, height: height)
      }

      // Default height (will be updated when image loads)
      return CGSize(width: width, height: width)
    }

    // MARK: - UICollectionViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
      isUserScrolling = true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      // Check if scrolled to bottom
      checkIfAtBottom(scrollView)

      // Only update page if user is scrolling (not programmatic scrolls)
      if isUserScrolling {
        // Update current page based on scroll position
        updateCurrentPage()

        // Preload nearby pages while scrolling (throttled)
        // Use a simple throttling mechanism to avoid too frequent calls
        let now = Date()
        if lastPreloadTime == nil || now.timeIntervalSince(lastPreloadTime!) > 0.3 {
          lastPreloadTime = now
          preloadNearbyPages()
        }
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
      // Delay clearing programmatic scrolling flag to prevent updateUIView from triggering additional scroll
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.isProgrammaticScrolling = false
      }
      updateCurrentPage()
      preloadNearbyPages()
    }

    private func checkIfAtBottom(_ scrollView: UIScrollView) {
      let contentHeight = scrollView.contentSize.height
      let scrollOffset = scrollView.contentOffset.y
      let scrollViewHeight = scrollView.bounds.height

      // Consider at bottom if within 120pt of the bottom (footer area is 320pt)
      let threshold: CGFloat = 120
      let isAtBottomNow = scrollOffset + scrollViewHeight >= contentHeight - threshold

      if isAtBottomNow != isAtBottom {
        isAtBottom = isAtBottomNow
        onScrollToBottom?(isAtBottom)
      }
    }

    private func updateCurrentPage() {
      guard let collectionView = collectionView else { return }

      // Find the page that is most visible in the center of the screen
      let centerY = collectionView.contentOffset.y + collectionView.bounds.height / 2
      let centerPoint = CGPoint(x: collectionView.bounds.width / 2, y: centerY)

      if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
        // Ignore footer cell
        if indexPath.item != pages.count && indexPath.item != currentPage && indexPath.item >= 0
          && indexPath.item < pages.count
        {
          currentPage = indexPath.item
          onPageChange?(indexPath.item)
        }
      } else {
        // Fallback: find closest page by checking visible items
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.filter {
          $0.item < pages.count
        }.sorted {
          $0.item < $1.item
        }
        if let firstVisible = visibleIndexPaths.first {
          let midIndex = firstVisible.item + visibleIndexPaths.count / 2
          if midIndex >= 0 && midIndex < pages.count && midIndex != currentPage {
            currentPage = midIndex
            onPageChange?(midIndex)
          }
        }
      }
    }

    // MARK: - Image Loading

    @MainActor
    func loadImageForPage(_ pageIndex: Int) async {
      guard pageIndex >= 0 && pageIndex < pages.count,
        pageImages[pageIndex] == nil,
        let loader = imageLoader
      else {
        return
      }

      // Mark as loading
      loadingPages.insert(pageIndex)
      defer { loadingPages.remove(pageIndex) }

      let image = await loader.loadImage(pageIndex)

      if let image = image {
        pageImages[pageIndex] = image

        // Calculate and cache height
        let screenWidth = collectionView?.bounds.width ?? UIScreen.main.bounds.width
        let width = screenWidth * (pageWidthPercentage / 100.0)
        let aspectRatio = image.size.height / image.size.width
        let height = width * aspectRatio

        // Get old height if exists
        let oldHeight = pageHeights[pageIndex] ?? screenWidth
        pageHeights[pageIndex] = height

        // Update visible cell if it exists
        if let collectionView = collectionView {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          if let cell = collectionView.cellForItem(at: indexPath) as? WebtoonPageCell {
            cell.updateImage(image)
          }
        }

        // Preserve scroll position when updating layout
        // Only update layout if height changed significantly and user is not scrolling
        if abs(height - oldHeight) > 100.0 && !isUserScrolling {
          if let collectionView = collectionView, let layout = layout {
            // Save current scroll position
            let currentOffset = collectionView.contentOffset.y

            // Calculate the difference in height
            let heightDiff = height - oldHeight

            // Invalidate layout to update cell size
            layout.invalidateLayout()
            collectionView.layoutIfNeeded()

            // Adjust scroll offset to maintain visual position
            // Only adjust if the updated page is above the current viewport
            // This prevents the scroll position from jumping when images load
            if pageIndex < currentPage {
              let newOffset = max(0, currentOffset + heightDiff)
              // Use performWithoutAnimation to avoid any visual glitches
              UIView.performWithoutAnimation {
                collectionView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
              }
            }
          }
        } else if abs(height - oldHeight) > 100.0 && isUserScrolling {
          // If user is scrolling, defer layout update until scrolling stops
          // This prevents scroll position jumping during user interaction
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isUserScrolling,
              let collectionView = self.collectionView,
              let layout = self.layout
            else { return }

            // Only update if height still differs
            let currentHeight = self.pageHeights[pageIndex] ?? 0
            if abs(currentHeight - oldHeight) > 100.0 {
              layout.invalidateLayout()
              collectionView.layoutIfNeeded()
            }
          }
        }

        // If we haven't scrolled to initial page yet, try scrolling after image loads
        if !hasScrolledToInitialPage && currentPage >= 0 && currentPage < pages.count {
          // If this is the initial page or nearby, try scrolling
          if abs(pageIndex - currentPage) <= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
              guard let self = self else { return }
              self.scrollToInitialPage(self.currentPage)
            }
          }
        }
      } else {
        // Image loading failed - update cell to show error state
        if let collectionView = collectionView,
          let cell = collectionView.cellForItem(at: IndexPath(item: pageIndex, section: 0))
            as? WebtoonPageCell
        {
          cell.showError()
        }
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

      for i in max(0, minVisible - 3)...min(pages.count - 1, maxVisible + 3) {
        if pageImages[i] == nil {
          Task { @MainActor [weak self] in
            guard let self = self else { return }
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

      // Get location in the view's coordinate space (screen coordinates)
      let location = gesture.location(in: view)
      let screenHeight = view.bounds.height
      let screenWidth = view.bounds.width

      // Check if tap is in top area (top 30%) or left area (left 30%)
      let isTopArea = location.y < screenHeight * 0.3
      let isLeftArea = location.x < screenWidth * 0.3

      // Check if tap is in bottom area (bottom 30%) or right area (right 30%)
      let isBottomArea = location.y > screenHeight * 0.7
      let isRightArea = location.x > screenWidth * 0.7

      // Check if tap is in center area (center 40% width and 40% height)
      let isCenterArea =
        location.x > screenWidth * 0.3
        && location.x < screenWidth * 0.7
        && location.y > screenHeight * 0.3
        && location.y < screenHeight * 0.7

      if isCenterArea {
        // Center tap - toggle controls
        onCenterTap?()
      } else if isTopArea || isLeftArea {
        // Scroll up by half screen
        isProgrammaticScrolling = true
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * 0.8
        let targetOffset = max(
          currentOffset - scrollAmount,
          0
        )

        collectionView.setContentOffset(
          CGPoint(x: 0, y: targetOffset),
          animated: true
        )
      } else if isBottomArea || isRightArea {
        // Scroll down by half screen
        isProgrammaticScrolling = true
        let currentOffset = collectionView.contentOffset.y
        let scrollAmount = screenHeight * 0.8
        let targetOffset = min(
          currentOffset + scrollAmount,
          collectionView.contentSize.height - screenHeight
        )

        collectionView.setContentOffset(
          CGPoint(x: 0, y: targetOffset),
          animated: true
        )
      }
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

  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    guard let attributes = super.layoutAttributesForElements(in: rect) else {
      return nil
    }

    // Center items horizontally if they are narrower than the collection view
    if let collectionView = collectionView {
      let collectionViewWidth = collectionView.bounds.width
      for attribute in attributes {
        if attribute.frame.width < collectionViewWidth {
          let centerX = collectionViewWidth / 2
          attribute.center = CGPoint(x: centerX, y: attribute.center.y)
        }
      }
    }

    return attributes
  }

  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
  {
    guard let attributes = super.layoutAttributesForItem(at: indexPath),
      let collectionView = collectionView
    else {
      return nil
    }

    // Center item horizontally if it is narrower than the collection view
    let collectionViewWidth = collectionView.bounds.width
    if attributes.frame.width < collectionViewWidth {
      let centerX = collectionViewWidth / 2
      attributes.center = CGPoint(x: centerX, y: attributes.center.y)
    }

    return attributes
  }
}

// MARK: - Custom Cell

class WebtoonPageCell: UICollectionViewCell {
  private let imageView = UIImageView()
  private let loadingIndicator = UIActivityIndicatorView(style: .medium)
  private var pageIndex: Int = -1
  private var loadImage: ((Int) async -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    contentView.backgroundColor = .black

    imageView.contentMode = .scaleAspectFit
    imageView.backgroundColor = .black
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(imageView)

    loadingIndicator.color = .white
    loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(loadingIndicator)

    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    ])
  }

  func configure(pageIndex: Int, image: UIImage?, loadImage: @escaping (Int) async -> Void) {
    self.pageIndex = pageIndex
    self.loadImage = loadImage

    if let image = image {
      imageView.image = image
      loadingIndicator.stopAnimating()
      loadingIndicator.isHidden = true
      imageView.alpha = 1.0
    } else {
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.startAnimating()
      loadingIndicator.isHidden = false
    }
  }

  func updateImage(_ image: UIImage) {
    imageView.image = image
    UIView.animate(withDuration: 0.2) {
      self.imageView.alpha = 1.0
    }
    loadingIndicator.stopAnimating()
    loadingIndicator.isHidden = true
  }

  func showError() {
    imageView.image = nil
    imageView.alpha = 0.0
    loadingIndicator.stopAnimating()
    loadingIndicator.isHidden = true
    // Could show an error indicator here if needed
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    imageView.image = nil
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
