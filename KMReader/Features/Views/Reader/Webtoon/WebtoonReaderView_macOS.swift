//
//  WebtoonReaderView_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(macOS)
  import AppKit
  import ImageIO
  import SwiftUI

  struct WebtoonReaderView: NSViewRepresentable {
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
      var disableTapToTurnPage: Bool = false
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
        self.disableTapToTurnPage = parent.disableTapToTurnPage
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

        // First check if image is already preloaded
        if let preloadedImage = vm.preloadedImages[page.number] {
          if let cv = collectionView,
            let cell = cv.item(at: IndexPath(item: pageIndex, section: 0)) as? WebtoonPageCell
          {
            cell.setImage(preloadedImage)
          }

          if let rep = preloadedImage.representations.first {
            let size = CGSize(width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh))
            let h = pageWidth * size.height / size.width
            let old = pageHeights[pageIndex] ?? pageWidth
            pageHeights[pageIndex] = h
            if abs(h - old) > 1 {
              layout?.invalidateLayout()
            }
          }
          return
        }

        // Fall back to loading from file
        guard let url = await vm.getPageImageFileURL(page: page) else { return }

        // Load image and get size in one operation
        var imageSize: CGSize?
        if let cv = collectionView,
          let cell = cv.item(at: IndexPath(item: pageIndex, section: 0)) as? WebtoonPageCell
        {
          imageSize = await cell.loadImageFromURL(url)
        }

        if let size = imageSize {
          let h = pageWidth * size.height / size.width
          let old = pageHeights[pageIndex] ?? pageWidth
          pageHeights[pageIndex] = h
          if abs(h - old) > 1 {
            layout?.invalidateLayout()
          }
        }
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
            // Skip if already preloaded
            if vm.preloadedImages[page.number] != nil {
              continue
            }
            if let fileURL = await vm.getPageImageFileURL(page: page) {
              // Load and decode image
              if let data = try? Data(contentsOf: fileURL) {
                if let image = NSImage(data: data) {
                  vm.preloadedImages[page.number] = image
                }
              }
            }
          }
        }
      }

      // MARK: - Click

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let sv = scrollView, let window = sv.window else { return }

        if disableTapToTurnPage {
          onCenterTap?()
          return
        }

        let locInWindow = gesture.location(in: nil)
        let windowHeight = window.contentView?.bounds.height ?? window.frame.height
        let loc = NSPoint(x: locInWindow.x, y: windowHeight - locInWindow.y)

        let h = windowHeight
        let w = window.contentView?.bounds.width ?? window.frame.width

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
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
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
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
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
