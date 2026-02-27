//
// WebtoonReaderView_macOS.swift
//
//

#if os(macOS)
  import AppKit
  import SwiftUI

  struct WebtoonReaderView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NSScrollView {
      let layout = WebtoonLayout()
      let collectionView = NSCollectionView()
      collectionView.collectionViewLayout = layout
      collectionView.delegate = context.coordinator
      collectionView.dataSource = context.coordinator
      collectionView.backgroundColors = [NSColor(renderConfig.readerBackground.color)]
      collectionView.isSelectable = false

      collectionView.register(
        WebtoonPageCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier("WebtoonPageCell"))
      collectionView.register(
        WebtoonFooterCell.self,
        forItemWithIdentifier: NSUserInterfaceItemIdentifier("WebtoonFooterCell"))

      let scrollView = NSScrollView()
      scrollView.documentView = collectionView
      scrollView.hasVerticalScroller = false
      scrollView.hasHorizontalScroller = false
      // scrollView.autohidesScrollers = true
      scrollView.backgroundColor = NSColor(renderConfig.readerBackground.color)
      scrollView.contentView.postsBoundsChangedNotifications = true

      let clickGesture = NSClickGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
      clickGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(clickGesture)

      let pressGesture = NSPressGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handlePress(_:)))
      pressGesture.minimumPressDuration = WebtoonConstants.longPressMinimumDuration
      pressGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(pressGesture)

      let magnifyGesture = NSMagnificationGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleMagnify(_:))
      )
      magnifyGesture.delegate = context.coordinator
      collectionView.addGestureRecognizer(magnifyGesture)

      context.coordinator.collectionView = collectionView
      context.coordinator.scrollView = scrollView
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
      scrollView.backgroundColor = NSColor(renderConfig.readerBackground.color)
      if let collectionView = scrollView.documentView as? NSCollectionView {
        collectionView.backgroundColors = [NSColor(renderConfig.readerBackground.color)]
        context.coordinator.update(
          viewModel: viewModel,
          readListContext: readListContext,
          onDismiss: onDismiss,
          onPageChange: onPageChange,
          onCenterTap: onCenterTap,
          onZoomRequest: onZoomRequest,
          pageWidth: pageWidth,
          collectionView: collectionView,
          renderConfig: renderConfig)
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
      var collectionView: NSCollectionView?
      var scrollView: NSScrollView?
      private var scrollEngine: WebtoonScrollEngine
      weak var viewModel: ReaderViewModel?
      var readListContext: ReaderReadListContext?
      var onDismiss: (() -> Void)?
      var onPageChange: ((Int) -> Void)?
      var onCenterTap: (() -> Void)?
      var onZoomRequest: ((Int, CGPoint) -> Void)?
      var lastPagesCount: Int = 0
      var isUserScrolling: Bool = false
      var isProgrammaticScrolling: Bool = false
      var pageWidth: CGFloat = 0
      var readerBackground: ReaderBackground = .system
      var tapZoneMode: TapZoneMode = .auto
      var tapZoneSize: TapZoneSize = .large
      var showPageNumber: Bool = true
      var isLongPress: Bool = false
      var heightCache = WebtoonPageHeightCache()
      var keyMonitor: Any?
      var lastScrollTime: TimeInterval = 0
      var hasTriggeredZoomGesture: Bool = false

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
        self.showPageNumber = parent.renderConfig.showPageNumber
        super.init()
        _ = scrollEngine.rebuildContentItemsIfNeeded(viewModel: viewModel)
      }

      private var pageCount: Int {
        viewModel?.pageCount ?? 0
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
        collectionView: NSCollectionView,
        renderConfig: ReaderRenderConfig
      ) {
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
          if isProgrammaticScrolling {
            scrollEngine.pendingReloadCurrentPageID = currentPageID
          } else {
            handleDataReload(collectionView: collectionView, currentPageID: currentPageID)
          }
        }

        for ip in collectionView.indexPathsForVisibleItems() {
          if ip.item < scrollEngine.contentItems.count,
            case .page = scrollEngine.contentItems[ip.item],
            let cell = collectionView.item(at: ip) as? WebtoonPageCell
          {
            cell.readerBackground = renderConfig.readerBackground
            cell.showPageNumber = renderConfig.showPageNumber
          } else if let cell = collectionView.item(at: ip) as? WebtoonFooterCell,
            ip.item < scrollEngine.contentItems.count,
            case .end(let segmentBookId) = scrollEngine.contentItems[ip.item]
          {
            cell.readerBackground = renderConfig.readerBackground
            cell.configure(
              previousBook: viewModel.currentBook(forSegmentBookId: segmentBookId),
              nextBook: viewModel.nextBook(forSegmentBookId: segmentBookId),
              readListContext: readListContext,
              onDismiss: onDismiss
            )
          }
        }

        if !scrollEngine.hasScrolledToInitialPage && scrollEngine.itemCount > 0 && currentPageID != nil {
          scrollToInitialPage(currentPageID)
        }

        if let target = viewModel.targetPageIndex,
          isValidPageIndex(target)
        {
          scrollToPage(target, animated: true)
          viewModel.targetPageIndex = nil
          if self.scrollEngine.currentPage != target {
            self.scrollEngine.currentPage = target
            self.scrollEngine.currentPageID = scrollEngine.pageID(
              forPageIndex: target,
              viewModel: viewModel
            )
            onPageChange?(target)
          }
        } else if self.scrollEngine.currentPage != currentPage, isValidPageIndex(currentPage) {
          self.scrollEngine.currentPage = currentPage
          self.scrollEngine.currentPageID = currentPageID
        }
      }

      private func handleDataReload(collectionView: NSCollectionView, currentPageID: ReaderPageID?) {
        let pageCount = self.pageCount
        let pagesChanged = lastPagesCount != pageCount
        let currentPageIndex = pageIndex(forPageID: currentPageID)
        let offsetWithinCurrentPage =
          scrollEngine.hasScrolledToInitialPage && currentPageIndex != nil
          ? captureOffsetWithinPage(currentPageIndex ?? 0) : nil

        if pagesChanged {
          heightCache.reset()
        }

        lastPagesCount = pageCount
        heightCache.rescaleIfNeeded(newWidth: pageWidth)
        collectionView.reloadData()
        collectionView.layoutSubtreeIfNeeded()

        if let offsetWithinCurrentPage,
          let currentPageIndex,
          restoreOffsetWithinPage(offsetWithinCurrentPage, for: currentPageIndex)
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

      private func captureOffsetWithinPage(_ pageIndex: Int) -> CGFloat? {
        guard let cv = collectionView, let sv = scrollView else { return nil }
        return WebtoonScrollOffset.captureOffsetWithinPage(
          pageIndex: pageIndex,
          currentTopY: sv.contentView.bounds.origin.y,
          isValidPage: isValidPageIndex,
          itemIndexForPage: itemIndex(forPageIndex:),
          frameForItemIndex: { itemIndex in
            cv.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
          }
        )
      }

      @discardableResult
      private func restoreOffsetWithinPage(_ offsetWithinPage: CGFloat, for pageIndex: Int) -> Bool {
        guard let cv = collectionView, let sv = scrollView else { return false }
        guard
          let targetY = WebtoonScrollOffset.targetTopYForPage(
            pageIndex: pageIndex,
            offsetWithinPage: offsetWithinPage,
            isValidPage: isValidPageIndex,
            itemIndexForPage: itemIndex(forPageIndex:),
            frameForItemIndex: { itemIndex in
              cv.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
            }
          )
        else {
          return false
        }

        let contentHeight = cv.collectionViewLayout?.collectionViewContentSize.height ?? 0
        let viewportHeight = sv.contentView.bounds.height
        let minY: CGFloat = 0
        let maxY = max(contentHeight - viewportHeight, minY)
        let clampedY = WebtoonScrollOffset.clampedY(targetY, min: minY, max: maxY)

        isProgrammaticScrolling = true
        sv.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        sv.reflectScrolledClipView(sv.contentView)
        Task { @MainActor [weak self] in
          self?.isProgrammaticScrolling = false
        }
        return true
      }

      private func applyPendingReloadIfNeeded() {
        guard let pendingPageID = scrollEngine.pendingReloadCurrentPageID else { return }
        guard let collectionView = collectionView else { return }
        scrollEngine.pendingReloadCurrentPageID = nil

        let currentPageID = viewModel?.currentReaderPage?.id ?? pendingPageID
        handleDataReload(collectionView: collectionView, currentPageID: currentPageID)
      }

      private func finalizeProgrammaticScroll() {
        isProgrammaticScrolling = false
        applyPendingReloadIfNeeded()
        updateCurrentPage()
      }

      private func finalizeScrollInteraction() {
        isUserScrolling = false
        updateCurrentPage()
        applyPendingReloadIfNeeded()
        updateCurrentPage()
        viewModel?.cleanupDistantImagesAroundCurrentPage()
      }

      func scrollToPage(_ pageIndex: Int, animated: Bool) {
        guard let cv = collectionView, isValidPageIndex(pageIndex) else { return }
        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return }
        let ip = IndexPath(item: itemIndex, section: 0)
        if let attr = cv.layoutAttributesForItem(at: ip) {
          isProgrammaticScrolling = true
          if animated {
            NSAnimationContext.runAnimationGroup {
              $0.duration = WebtoonConstants.scrollAnimationDuration
              cv.animator().scroll(attr.frame.origin)
            } completionHandler: { [weak self] in
              Task { @MainActor [weak self] in
                self?.finalizeProgrammaticScroll()
              }
            }
          } else {
            cv.scroll(attr.frame.origin)
            // Reset flag after immediate scroll
            Task { @MainActor [weak self] in
              self?.finalizeProgrammaticScroll()
            }
          }
        }
      }

      func scrollToInitialPage(_ pageID: ReaderPageID?) {
        guard !scrollEngine.hasScrolledToInitialPage,
          let pageIndex = pageIndex(forPageID: pageID),
          let cv = collectionView, isValidPageIndex(pageIndex),
          cv.bounds.width > 0
        else {
          if !scrollEngine.hasScrolledToInitialPage {
            requestInitialScroll(pageID, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }
        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return }
        let ip = IndexPath(item: itemIndex, section: 0)
        if let attr = cv.layoutAttributesForItem(at: ip) {
          scrollEngine.hasScrolledToInitialPage = true
          isProgrammaticScrolling = true
          cv.scroll(attr.frame.origin)
          // Reset flag after immediate scroll
          Task { @MainActor [weak self] in
            self?.finalizeProgrammaticScroll()
          }
        } else {
          requestInitialScroll(pageID, delay: WebtoonConstants.initialScrollRetryDelay)
        }
      }

      // MARK: - DataSource

      func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int)
        -> Int
      { scrollEngine.itemCount }

      func collectionView(
        _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath
      ) -> NSCollectionViewItem {
        guard indexPath.item < scrollEngine.contentItems.count else {
          return NSCollectionViewItem()
        }

        switch scrollEngine.contentItems[indexPath.item] {
        case .end(let segmentBookId):
          let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("WebtoonFooterCell"),
            for: indexPath
          )
          guard let cell = item as? WebtoonFooterCell else {
            assertionFailure("Failed to make WebtoonFooterCell")
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
            return NSCollectionViewItem()
          }

          let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("WebtoonPageCell"),
            for: indexPath
          )
          guard let cell = item as? WebtoonPageCell else {
            assertionFailure("Failed to make WebtoonPageCell")
            return item
          }
          cell.readerBackground = readerBackground
          let preloadedImage = viewModel?.preloadedImage(forPageIndex: pageIndex)
          let displayedPageNumber = viewModel?.displayPageNumber(forPageIndex: pageIndex)

          cell.configure(
            pageIndex: pageIndex,
            displayPageNumber: displayedPageNumber,
            image: preloadedImage,
            showPageNumber: showPageNumber
          ) { [weak self] idx in
            guard let self = self else { return }
            if let image = self.viewModel?.preloadedImage(forPageIndex: idx) {
              if let cv = self.collectionView,
                let itemIndex = self.itemIndex(forPageIndex: idx),
                let cell = cv.item(at: IndexPath(item: itemIndex, section: 0)) as? WebtoonPageCell
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
      }

      func collectionView(
        _ collectionView: NSCollectionView, layout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
      ) -> NSSize {
        guard indexPath.item < scrollEngine.contentItems.count else {
          return NSSize(width: pageWidth, height: 0)
        }

        switch scrollEngine.contentItems[indexPath.item] {
        case .end:
          return NSSize(width: pageWidth, height: WebtoonConstants.footerHeight)
        case .page(let pageID):
          guard let pageIndex = pageIndex(forPageID: pageID) else {
            return NSSize(width: pageWidth, height: pageWidth * 3)
          }
          guard let page = viewModel?.page(at: pageIndex) else {
            return NSSize(width: pageWidth, height: pageWidth * 3)
          }
          let height = heightCache.height(for: pageIndex, page: page, pageWidth: pageWidth)
          let scale = collectionView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
          let alignedHeight = scale > 0 ? ceil(height * scale) / scale : height
          return NSSize(width: pageWidth, height: alignedHeight)
        }
      }

      // MARK: - Scroll

      @objc func scrollViewDidScroll(_ notification: Notification) {
        if !isProgrammaticScrolling {
          isUserScrolling = true
        }
        lastScrollTime = Date().timeIntervalSinceReferenceDate
        updateCurrentPage()
      }

      @objc func scrollViewDidEndScroll(_ notification: Notification) {
        finalizeScrollInteraction()
      }

      private func updateCurrentPage() {
        guard let cv = collectionView, let sv = scrollView else { return }
        let totalItems = scrollEngine.itemCount
        guard totalItems > 0 else { return }

        let offset = sv.contentView.bounds.origin.y
        let viewHeight = sv.contentView.bounds.height
        let viewportBottom = offset + viewHeight
        let visibleItemIndices = cv.indexPathsForVisibleItems().map(\.item)

        let newCurrentItemIndex = WebtoonContentItems.lastVisibleItemIndex(
          itemCount: totalItems,
          viewportBottom: viewportBottom,
          threshold: WebtoonConstants.bottomThreshold,
          visibleItemIndices: visibleItemIndices
        ) { itemIndex in
          cv.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
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
        guard isValidPageIndex(pageIndex), let vm = viewModel else { return }

        // First check if image is already preloaded
        if let preloadedImage = vm.preloadedImage(forPageIndex: pageIndex) {
          pageCell(forPageIndex: pageIndex)?.setImage(preloadedImage)
          return
        }

        if let image = await vm.preloadImageForPage(at: pageIndex) {
          pageCell(forPageIndex: pageIndex)?.setImage(image)
        }
      }

      private func pageCell(forPageIndex pageIndex: Int) -> WebtoonPageCell? {
        guard let cv = collectionView else { return nil }
        guard let itemIndex = itemIndex(forPageIndex: pageIndex) else { return nil }
        return cv.item(at: IndexPath(item: itemIndex, section: 0)) as? WebtoonPageCell
      }

      // MARK: - Click

      @objc func handlePress(_ gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
          isLongPress = true
        } else if gesture.state == .ended || gesture.state == .cancelled {
          DispatchQueue.main.asyncAfter(deadline: .now() + WebtoonConstants.longPressReleaseDelay) {
            [weak self] in
            self?.isLongPress = false
          }
        }
      }

      @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard !isLongPress else { return }

        if isUserScrolling { return }

        if Date().timeIntervalSinceReferenceDate - lastScrollTime < WebtoonConstants.clickDebounceAfterScroll {
          return
        }

        guard let sv = scrollView, let window = sv.window, let cv = collectionView else { return }

        let locationInCollection = gesture.location(in: cv)
        if let indexPath = cv.indexPathForItem(at: locationInCollection),
          indexPath.item < scrollEngine.contentItems.count,
          case .end = scrollEngine.contentItems[indexPath.item],
          let footerCell = cv.item(at: indexPath) as? WebtoonFooterCell,
          footerCell.isInteractingWithCloseButton(at: locationInCollection, in: cv)
        {
          return
        }

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
          zoneThreshold: tapZoneSize.value
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

      @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
        guard let cv = collectionView else { return }

        switch gesture.state {
        case .began:
          hasTriggeredZoomGesture = false
        case .changed:
          if hasTriggeredZoomGesture { return }
          let delta = gesture.magnification
          guard delta > 0.05 else { return }
          hasTriggeredZoomGesture = true
          let location = gesture.location(in: cv)
          requestZoom(at: location)
        case .ended, .cancelled, .failed:
          hasTriggeredZoomGesture = false
        default:
          break
        }
      }

      private func scrollUp(_ screenHeight: CGFloat) {
        guard let sv = scrollView else { return }
        let currentOrigin = sv.contentView.bounds.origin
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let targetY = max(currentOrigin.y - scrollAmount, 0)
        scrollToOffsetIfNeeded(targetY, in: sv)
      }

      private func scrollDown(_ screenHeight: CGFloat) {
        guard let sv = scrollView, let cv = collectionView else { return }
        let currentOrigin = sv.contentView.bounds.origin
        let contentH = cv.collectionViewLayout?.collectionViewContentSize.height ?? 0
        let scrollAmount = screenHeight * CGFloat(AppConfig.webtoonTapScrollPercentage / 100.0)
        let maxY = max(contentH - screenHeight, 0)
        let targetY = min(currentOrigin.y + scrollAmount, maxY)
        scrollToOffsetIfNeeded(targetY, in: sv)
      }

      private func scrollToOffsetIfNeeded(_ targetY: CGFloat, in scrollView: NSScrollView) {
        let clipView = scrollView.contentView
        let currentY = clipView.bounds.origin.y
        guard abs(targetY - currentY) > WebtoonConstants.offsetEpsilon else {
          isProgrammaticScrolling = false
          return
        }

        preheatPages(at: targetY)

        isProgrammaticScrolling = true
        NSAnimationContext.runAnimationGroup { context in
          context.duration = WebtoonConstants.scrollAnimationDuration
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          context.allowsImplicitAnimation = true
          clipView.animator().scroll(to: NSPoint(x: 0, y: targetY))
        } completionHandler: { [weak self, weak scrollView, weak clipView] in
          Task { @MainActor [weak self, weak scrollView, weak clipView] in
            self?.finalizeProgrammaticScroll()
            guard let scrollView, let clipView else { return }
            scrollView.reflectScrolledClipView(clipView)
          }
        }
      }

      private func preheatPages(at targetOffset: CGFloat) {
        guard let cv = collectionView, let sv = scrollView else { return }
        let centerY = targetOffset + sv.contentView.bounds.height / 2
        let centerPoint = NSPoint(x: cv.bounds.width / 2, y: centerY)
        guard let indexPath = cv.indexPathForItem(at: centerPoint),
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

      func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
      ) -> Bool {
        return true
      }

      private func requestZoom(at location: NSPoint) {
        guard let result = pageIndexAndAnchor(for: location) else { return }
        onZoomRequest?(result.pageIndex, result.anchor)
      }

      private func pageIndexAndAnchor(for location: NSPoint) -> (pageIndex: Int, anchor: CGPoint)? {
        guard let cv = collectionView else { return nil }
        let totalPages = self.pageCount

        if let indexPath = cv.indexPathForItem(at: location),
          let pageIndex = scrollEngine.resolvedPageIndex(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          ),
          isValidPageIndex(pageIndex)
        {
          if let item = cv.item(at: indexPath) {
            let local = item.view.convert(location, from: cv)
            return (
              pageIndex,
              normalizedAnchor(in: item.view.bounds, location: local, isFlipped: item.view.isFlipped)
            )
          }
          if let attributes = cv.layoutAttributesForItem(at: indexPath) {
            return (
              pageIndex,
              normalizedAnchor(in: attributes.frame, location: location, isFlipped: cv.isFlipped)
            )
          }
        }

        guard totalPages > 0 else { return nil }
        let fallback = min(max(scrollEngine.currentPage, 0), totalPages - 1)
        guard isValidPageIndex(fallback) else { return nil }
        guard let itemIndex = itemIndex(forPageIndex: fallback) else { return nil }
        let fallbackIndexPath = IndexPath(item: itemIndex, section: 0)
        if let item = cv.item(at: fallbackIndexPath) {
          let local = item.view.convert(location, from: cv)
          return (
            fallback,
            normalizedAnchor(in: item.view.bounds, location: local, isFlipped: item.view.isFlipped)
          )
        }
        if let attributes = cv.layoutAttributesForItem(at: fallbackIndexPath) {
          return (
            fallback,
            normalizedAnchor(in: attributes.frame, location: location, isFlipped: cv.isFlipped)
          )
        }
        return nil
      }

      private func normalizedAnchor(in frame: NSRect, location: NSPoint, isFlipped: Bool) -> CGPoint {
        guard frame.width > 0, frame.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let localX = location.x - frame.minX
        let localY = location.y - frame.minY
        let x = min(max(localX / frame.width, 0), 1)
        let rawY = min(max(localY / frame.height, 0), 1)
        let y = isFlipped ? rawY : 1.0 - rawY
        return CGPoint(x: x, y: y)
      }
    }
  }
#endif
