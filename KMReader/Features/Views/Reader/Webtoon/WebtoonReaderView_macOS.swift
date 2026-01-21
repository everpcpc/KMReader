//
//  WebtoonReaderView_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(macOS)
  import AppKit
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
    let tapZoneMode: TapZoneMode
    let showPageNumber: Bool

    init(
      pages: [BookPage], viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      readerBackground: ReaderBackground,
      tapZoneMode: TapZoneMode = .auto,
      showPageNumber: Bool = true,
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
      self.tapZoneMode = tapZoneMode
      self.showPageNumber = showPageNumber
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
      clickGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(clickGesture)

      let pressGesture = NSPressGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handlePress(_:)))
      pressGesture.minimumPressDuration = 0.5
      pressGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(pressGesture)

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
          readerBackground: readerBackground,
          showPageNumber: showPageNumber)
      }
    }

    @MainActor
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
      coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource,
      NSCollectionViewDelegateFlowLayout, NSGestureRecognizerDelegate
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
      var isProgrammaticScrolling: Bool = false
      var hasScrolledToInitialPage: Bool = false
      var initialScrollRetrier = InitialScrollRetrier(
        maxRetries: WebtoonConstants.initialScrollMaxRetries
      )
      var pageWidth: CGFloat = 0
      var isAtBottom: Bool = false
      var lastTargetPageIndex: Int?
      var readerBackground: ReaderBackground = .system
      var tapZoneMode: TapZoneMode = .auto
      var showPageNumber: Bool = true
      var isLongPress: Bool = false
      var heightCache = WebtoonPageHeightCache()
      var keyMonitor: Any?
      var lastScrollTime: TimeInterval = 0

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
        self.heightCache.lastPageWidth = parent.pageWidth
        self.readerBackground = parent.readerBackground
        self.tapZoneMode = parent.tapZoneMode
      }

      deinit {
        Task { @MainActor [weak self] in
          self?.teardown()
        }
      }

      func teardown() {
        NotificationCenter.default.removeObserver(self)
        if let monitor = keyMonitor {
          NSEvent.removeMonitor(monitor)
          keyMonitor = nil
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

      func scheduleInitialScroll() {
        initialScrollRetrier.reset()
        requestInitialScroll(currentPage, delay: WebtoonConstants.initialScrollDelay)
      }

      @MainActor
      func executeAfterDelay(
        _ delay: TimeInterval,
        _ block: @MainActor @Sendable @escaping () -> Void
      ) {
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          block()
        }
      }

      func requestInitialScroll(_ pageIndex: Int, delay: TimeInterval) {
        initialScrollRetrier.schedule(
          after: delay,
          using: executeAfterDelay
        ) { [weak self] in
          guard let self = self, !self.hasScrolledToInitialPage,
            self.pages.count > 0, self.isValidPageIndex(pageIndex)
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
        pageWidth: CGFloat,
        collectionView: NSCollectionView,
        readerBackground: ReaderBackground,
        showPageNumber: Bool
      ) {
        self.pages = pages
        self.viewModel = viewModel
        self.onPageChange = onPageChange
        self.onCenterTap = onCenterTap
        self.onScrollToBottom = onScrollToBottom
        self.pageWidth = pageWidth
        self.readerBackground = readerBackground

        let currentPage = viewModel.currentPageIndex

        if self.showPageNumber != showPageNumber {
          self.showPageNumber = showPageNumber
          for ip in collectionView.indexPathsForVisibleItems() {
            if ip.item < pages.count,
              let cell = collectionView.item(at: ip) as? WebtoonPageCell
            {
              cell.showPageNumber = showPageNumber
            }
          }
        }

        if lastPagesCount != pages.count || abs(heightCache.lastPageWidth - pageWidth) > 0.1 {
          if lastPagesCount != pages.count {
            heightCache.reset()
          }
          lastPagesCount = pages.count
          hasScrolledToInitialPage = false
          initialScrollRetrier.reset()
          heightCache.rescaleIfNeeded(newWidth: pageWidth)
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
          isProgrammaticScrolling = true
          if animated {
            NSAnimationContext.runAnimationGroup {
              $0.duration = 0.3
              cv.animator().scroll(attr.frame.origin)
            } completionHandler: { [weak self] in
              Task { @MainActor [weak self] in
                self?.isProgrammaticScrolling = false
              }
            }
          } else {
            cv.scroll(attr.frame.origin)
            // Reset flag after immediate scroll
            Task { @MainActor [weak self] in
              self?.isProgrammaticScrolling = false
            }
          }
        }
      }

      func scrollToInitialPage(_ pageIndex: Int) {
        guard !hasScrolledToInitialPage,
          let cv = collectionView, isValidPageIndex(pageIndex),
          cv.bounds.width > 0
        else {
          requestInitialScroll(pageIndex, delay: WebtoonConstants.initialScrollRetryDelay)
          return
        }
        let ip = IndexPath(item: pageIndex, section: 0)
        if let attr = cv.layoutAttributesForItem(at: ip) {
          isProgrammaticScrolling = true
          cv.scroll(attr.frame.origin)
          // Reset flag after immediate scroll
          Task { @MainActor [weak self] in
            self?.isProgrammaticScrolling = false
          }
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
        let preloadedImage = viewModel?.preloadedImages[pageIndex]

        cell.configure(pageIndex: pageIndex, image: preloadedImage, showPageNumber: showPageNumber) {
          [weak self] idx in
          guard let self = self else { return }
          if let image = self.viewModel?.preloadedImages[idx] {
            if let cv = self.collectionView,
              let cell = cv.item(at: IndexPath(item: idx, section: 0)) as? WebtoonPageCell
            {
              cell.setImage(image)
            }
            return
          }
          Task { @MainActor in await self.loadImageForPage(idx) }
        }

        if preloadedImage == nil {
          Task { @MainActor [weak self] in
            await self?.loadImageForPage(pageIndex)
          }
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
        let page = pages[indexPath.item]
        let height = heightCache.height(for: indexPath.item, page: page, pageWidth: pageWidth)
        let scale = collectionView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        let alignedHeight = scale > 0 ? ceil(height * scale) / scale : height
        return NSSize(width: pageWidth, height: alignedHeight)
      }

      // MARK: - Scroll

      @objc func scrollViewDidScroll(_ notification: Notification) {
        guard let sv = scrollView else { return }
        if !isProgrammaticScrolling {
          isUserScrolling = true
        }
        lastScrollTime = Date().timeIntervalSinceReferenceDate
        checkIfAtBottom(sv)
        updateCurrentPage()
      }

      @objc func scrollViewDidEndScroll(_ notification: Notification) {
        guard let sv = scrollView else { return }
        isUserScrolling = false
        checkIfAtBottom(sv)
        updateCurrentPage()
        viewModel?.cleanupDistantImagesAroundCurrentPage()
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

        // When at bottom (showing end page), set currentPage to pages.count to show "END"
        if isAtBottom {
          if currentPage != pages.count {
            currentPage = pages.count
            onPageChange?(pages.count)
          }
          return
        }

        let offset = sv.contentView.bounds.origin.y
        let viewHeight = sv.contentView.bounds.height
        let viewportBottom = offset + viewHeight

        // Find the page whose bottom edge just passed the viewport bottom (with threshold)
        var newCurrentPage = 0
        for pageIndex in 0..<pages.count {
          let indexPath = IndexPath(item: pageIndex, section: 0)
          guard let frame = cv.layoutAttributesForItem(at: indexPath)?.frame else {
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
        guard isValidPageIndex(pageIndex), let vm = viewModel else { return }

        // First check if image is already preloaded
        if let preloadedImage = vm.preloadedImages[pageIndex] {
          if let cv = collectionView,
            let cell = cv.item(at: IndexPath(item: pageIndex, section: 0)) as? WebtoonPageCell
          {
            cell.setImage(preloadedImage)
          }
          return
        }

        let page = pages[pageIndex]
        if let image = await vm.preloadImageForPage(page) {
          if let cv = collectionView,
            let cell = cv.item(at: IndexPath(item: pageIndex, section: 0)) as? WebtoonPageCell
          {
            cell.setImage(image)
          }
        }
      }

      // MARK: - Click

      @objc func handlePress(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPress = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isLongPress = false
          }
        }
      }

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard !isLongPress else { return }

        if isUserScrolling { return }

        if Date().timeIntervalSinceReferenceDate - lastScrollTime < 0.25 { return }

        guard let sv = scrollView, let window = sv.window else { return }

        let locInWindow = gesture.location(in: nil)
        let windowHeight = window.contentView?.bounds.height ?? window.frame.height
        let loc = NSPoint(x: locInWindow.x, y: windowHeight - locInWindow.y)

        let h = windowHeight
        let w = window.contentView?.bounds.width ?? window.frame.width

        let normalizedX = loc.x / w
        let normalizedY = loc.y / h

        let action = TapZoneHelper.action(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          tapZoneMode: tapZoneMode,
          readingDirection: .webtoon,
          zoneThreshold: AppConfig.tapZoneSize.value
        )

        switch action {
        case .previous:
          scrollUp(h)
        case .next:
          scrollDown(h)
        case .toggleControls:
          onCenterTap?()
        }
      }

      private func scrollUp(_ screenHeight: CGFloat) {
        guard let sv = scrollView else { return }
        let clipView = sv.contentView
        let currentOrigin = clipView.bounds.origin
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetY = max(currentOrigin.y - scrollAmount, 0)
        preheatPages(at: targetY)

        isProgrammaticScrolling = true
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          context.allowsImplicitAnimation = true
          clipView.animator().scroll(to: NSPoint(x: 0, y: targetY))
        } completionHandler: { [weak self, weak sv] in
          Task { @MainActor [weak self, weak sv] in
            self?.isProgrammaticScrolling = false
            guard let sv = sv else { return }
            sv.reflectScrolledClipView(clipView)
          }
        }
      }

      private func scrollDown(_ screenHeight: CGFloat) {
        guard let sv = scrollView, let cv = collectionView else { return }
        let clipView = sv.contentView
        let currentOrigin = clipView.bounds.origin
        let contentH = cv.collectionViewLayout?.collectionViewContentSize.height ?? 0
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let maxY = max(contentH - screenHeight, 0)
        let targetY = min(currentOrigin.y + scrollAmount, maxY)
        preheatPages(at: targetY)

        isProgrammaticScrolling = true
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.3
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          context.allowsImplicitAnimation = true
          clipView.animator().scroll(to: NSPoint(x: 0, y: targetY))
        } completionHandler: { [weak self, weak sv] in
          Task { @MainActor [weak self, weak sv] in
            self?.isProgrammaticScrolling = false
            guard let sv = sv else { return }
            sv.reflectScrolledClipView(clipView)
          }
        }
      }

      private func preheatPages(at targetOffset: CGFloat) {
        guard let cv = collectionView, let sv = scrollView else { return }
        let centerY = targetOffset + sv.contentView.bounds.height / 2
        let centerPoint = NSPoint(x: cv.bounds.width / 2, y: centerY)
        guard let indexPath = cv.indexPathForItem(at: centerPoint),
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

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        return true
      }
    }
  }
#endif
