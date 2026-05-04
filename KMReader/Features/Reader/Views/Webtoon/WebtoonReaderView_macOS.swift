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
    let onCenterTap: (() -> Void)?
    let onZoomRequest: ((ReaderPageID, CGPoint) -> Void)?
    let pageWidth: CGFloat
    let renderConfig: ReaderRenderConfig
    let scrollController: WebtoonScrollController

    init(
      viewModel: ReaderViewModel,
      pageWidth: CGFloat,
      renderConfig: ReaderRenderConfig,
      readListContext: ReaderReadListContext? = nil,
      onDismiss: @escaping () -> Void = {},
      onCenterTap: (() -> Void)? = nil,
      onZoomRequest: ((ReaderPageID, CGPoint) -> Void)? = nil,
      scrollController: WebtoonScrollController
    ) {
      self.viewModel = viewModel
      self.pageWidth = pageWidth
      self.renderConfig = renderConfig
      self.readListContext = readListContext
      self.onDismiss = onDismiss
      self.onCenterTap = onCenterTap
      self.onZoomRequest = onZoomRequest
      self.scrollController = scrollController
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
      scrollController.target = context.coordinator
      context.coordinator.scheduleInitialScroll()

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
          onCenterTap: onCenterTap,
          onZoomRequest: onZoomRequest,
          pageWidth: pageWidth,
          collectionView: collectionView,
          renderConfig: renderConfig)
        context.coordinator.scrollController = scrollController
        scrollController.target = context.coordinator
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
      NSCollectionViewDelegateFlowLayout, NSGestureRecognizerDelegate, WebtoonScrollCommandHandling
    {
      var collectionView: NSCollectionView?
      var scrollView: NSScrollView?
      private var scrollEngine: WebtoonScrollEngine
      weak var viewModel: ReaderViewModel?
      var readListContext: ReaderReadListContext?
      var onDismiss: (() -> Void)?
      var onCenterTap: (() -> Void)?
      var onZoomRequest: ((ReaderPageID, CGPoint) -> Void)?
      weak var scrollController: WebtoonScrollController?
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
      var lastScrollTime: TimeInterval = 0
      var hasTriggeredZoomGesture: Bool = false
      private var deferredReloadWorkItem: DispatchWorkItem?
      private var deferredCleanupWorkItem: DispatchWorkItem?
      private var sizeProbeTasks: [ReaderPageID: Task<Void, Never>] = [:]
      private var pendingMeasuredPageIDs: Set<ReaderPageID> = []

      private struct ScrollAnchor {
        let pageID: ReaderPageID
        let offsetWithinPage: CGFloat
      }

      init(_ parent: WebtoonReaderView) {
        self.scrollEngine = WebtoonScrollEngine(
          initialPageID: parent.viewModel.currentReaderPage?.id
        )
        self.viewModel = parent.viewModel
        self.readListContext = parent.readListContext
        self.onDismiss = parent.onDismiss
        self.onCenterTap = parent.onCenterTap
        self.onZoomRequest = parent.onZoomRequest
        self.scrollController = parent.scrollController
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

      private var isScrollInteractionActive: Bool {
        isUserScrolling || isProgrammaticScrolling
      }

      func teardown() {
        scrollController?.clearTarget(self)
        cancelDeferredMaintenance()
        sizeProbeTasks.values.forEach { $0.cancel() }
        sizeProbeTasks.removeAll()
        pendingMeasuredPageIDs.removeAll()
        NotificationCenter.default.removeObserver(self)
      }

      private func itemIndex(forPageID pageID: ReaderPageID?) -> Int? {
        scrollEngine.itemIndex(forPageID: pageID)
      }

      private func indexPath(forPageID pageID: ReaderPageID?) -> IndexPath? {
        guard let itemIndex = itemIndex(forPageID: pageID) else { return nil }
        return IndexPath(item: itemIndex, section: 0)
      }

      private func currentAnchorPageID(preferredPageID: ReaderPageID? = nil) -> ReaderPageID? {
        preferredPageID ?? scrollEngine.currentPageID ?? viewModel?.currentReaderPage?.id
      }

      private func captureScrollAnchor(preferredPageID: ReaderPageID? = nil) -> ScrollAnchor? {
        guard collectionView != nil else { return nil }
        guard scrollEngine.hasScrolledToInitialPage else { return nil }
        guard let pageID = currentAnchorPageID(preferredPageID: preferredPageID) else { return nil }
        guard let offsetWithinPage = captureOffsetWithinPage(pageID) else { return nil }
        return ScrollAnchor(pageID: pageID, offsetWithinPage: offsetWithinPage)
      }

      @discardableResult
      private func restoreScrollAnchor(_ anchor: ScrollAnchor?) -> Bool {
        guard let anchor else { return false }
        return restoreOffsetWithinPage(anchor.offsetWithinPage, for: anchor.pageID)
      }

      private func currentContentPageIDs() -> Set<ReaderPageID> {
        Set(
          scrollEngine.contentItems.compactMap { item in
            guard case .page(let pageID) = item else { return nil }
            return pageID
          }
        )
      }

      private func pruneStaleMeasurementState() {
        let validPageIDs = currentContentPageIDs()
        heightCache.retainHeights(for: validPageIDs)
        pendingMeasuredPageIDs.formIntersection(validPageIDs)

        let stalePageIDs = sizeProbeTasks.keys.filter { !validPageIDs.contains($0) }
        for pageID in stalePageIDs {
          sizeProbeTasks[pageID]?.cancel()
          sizeProbeTasks.removeValue(forKey: pageID)
        }
      }

      private func hasKnownHeight(for pageID: ReaderPageID, page: BookPage?) -> Bool {
        if heightCache.hasHeight(for: pageID) {
          return true
        }

        guard let page else { return false }
        return (page.width ?? 0) > 0 && (page.height ?? 0) > 0
      }

      private func applyMeasuredHeightIfNeeded(for pageID: ReaderPageID, pixelSize: CGSize) {
        guard heightCache.updateHeight(for: pageID, pixelSize: pixelSize, pageWidth: pageWidth) else {
          return
        }
        if isScrollInteractionActive {
          pendingMeasuredPageIDs.insert(pageID)
        } else {
          invalidateLayout(for: pageID)
        }
      }

      private func invalidateLayout(for pageID: ReaderPageID) {
        guard let collectionView, let indexPath = indexPath(forPageID: pageID) else { return }
        let scrollAnchor = captureScrollAnchor()
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0
          collectionView.reloadItems(at: Set([indexPath]))
          collectionView.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
          Task { @MainActor [weak self] in
            guard let self else { return }
            _ = self.restoreScrollAnchor(scrollAnchor)
            self.updateCurrentPage()
          }
        }
      }

      private func applyPendingMeasuredLayoutUpdatesIfNeeded() {
        guard !pendingMeasuredPageIDs.isEmpty else { return }
        guard let collectionView else { return }

        let scrollAnchor = captureScrollAnchor()
        let indexPaths = pendingMeasuredPageIDs.compactMap { indexPath(forPageID: $0) }
        pendingMeasuredPageIDs.removeAll()
        guard !indexPaths.isEmpty else { return }

        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0
          collectionView.reloadItems(at: Set(indexPaths))
          collectionView.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
          Task { @MainActor [weak self] in
            guard let self else { return }
            if !self.restoreScrollAnchor(scrollAnchor),
              let pageID = scrollAnchor?.pageID
            {
              self.requestInitialScroll(pageID, delay: WebtoonConstants.layoutReadyDelay)
            }
            self.updateCurrentPage()
          }
        }
      }

      private func ensureMeasuredHeightProbe(for pageID: ReaderPageID, page: BookPage?) {
        guard !hasKnownHeight(for: pageID, page: page) else { return }
        guard sizeProbeTasks[pageID] == nil else { return }
        guard let viewModel else { return }

        sizeProbeTasks[pageID] = Task { @MainActor [weak self, weak viewModel] in
          defer { self?.sizeProbeTasks[pageID] = nil }
          guard let self, let viewModel else { return }
          guard let fileURL = await viewModel.getPageImageFileURL(pageID: pageID) else { return }
          guard let pixelSize = webtoonProbePixelSize(at: fileURL) else { return }
          self.applyMeasuredHeightIfNeeded(for: pageID, pixelSize: pixelSize)
        }
      }

      private func displayImageIfReady(
        _ image: PlatformImage?,
        for pageID: ReaderPageID,
        page: BookPage?
      ) -> PlatformImage? {
        guard let image else { return nil }
        if let pixelSize = webtoonPixelSize(from: image) {
          _ = heightCache.updateHeight(for: pageID, pixelSize: pixelSize, pageWidth: pageWidth)
        }
        return hasKnownHeight(for: pageID, page: page) ? image : nil
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
        collectionView: NSCollectionView,
        renderConfig: ReaderRenderConfig
      ) {
        self.viewModel = viewModel
        self.readListContext = readListContext
        self.onDismiss = onDismiss
        self.onCenterTap = onCenterTap
        self.onZoomRequest = onZoomRequest
        self.pageWidth = pageWidth
        self.readerBackground = renderConfig.readerBackground
        self.tapZoneMode = renderConfig.tapZoneMode
        self.tapZoneSize = renderConfig.tapZoneSize
        self.showPageNumber = renderConfig.showPageNumber

        let currentPageID = viewModel.currentReaderPage?.id
        scrollEngine.currentPageID = currentPageID
        let needsContentRebuild = scrollEngine.needsRebuild(viewModel: viewModel)
        let needsReload =
          needsContentRebuild
          || lastPagesCount != viewModel.pageCount
          || abs(heightCache.lastPageWidth - pageWidth) > 0.1

        if needsReload {
          if isScrollInteractionActive {
            let preCapturedOffset =
              scrollEngine.hasScrolledToInitialPage
              ? captureOffsetWithinPage(currentPageID) : nil
            scrollEngine.pendingReloadCurrentPageID = currentPageID ?? scrollEngine.currentPageID
            scrollEngine.pendingReloadPreCapturedOffset = preCapturedOffset
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
              previousBook: viewModel.endPagePreviousBook(forSegmentBookId: segmentBookId),
              nextBook: viewModel.nextBook(forSegmentBookId: segmentBookId),
              readListContext: readListContext,
              onDismiss: onDismiss
            )
          }
        }

        if !scrollEngine.hasScrolledToInitialPage && scrollEngine.itemCount > 0 && currentPageID != nil {
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
        } else if self.scrollEngine.currentPageID != currentPageID {
          self.scrollEngine.currentPageID = currentPageID
        }
      }

      private func handleDataReload(
        collectionView: NSCollectionView,
        currentPageID: ReaderPageID?,
        preCapturedOffset: CGFloat? = nil
      ) {
        let anchorPageID = currentAnchorPageID(preferredPageID: currentPageID)
        let scrollAnchor =
          captureScrollAnchor(preferredPageID: anchorPageID)
          ?? preCapturedOffset.flatMap { offsetWithinPage in
            anchorPageID.map {
              ScrollAnchor(pageID: $0, offsetWithinPage: offsetWithinPage)
            }
          }

        // Rebuild content items (updates index mapping to NEW)
        scrollEngine.rebuildContentItemsIfNeeded(viewModel: viewModel)
        pruneStaleMeasurementState()

        let pageCount = self.pageCount
        lastPagesCount = pageCount

        // Reload collection view (layout now matches NEW indices)
        heightCache.rescaleIfNeeded(newWidth: pageWidth)
        collectionView.reloadData()
        collectionView.layoutSubtreeIfNeeded()

        // Restore offset using NEW indices + NEW layout (consistent)
        if restoreScrollAnchor(scrollAnchor) {
          scrollEngine.hasScrolledToInitialPage = true
          return
        }

        scrollEngine.hasScrolledToInitialPage = false
        scrollEngine.resetInitialScrollRetrier()
        if let fallbackPageID = scrollAnchor?.pageID ?? anchorPageID {
          requestInitialScroll(fallbackPageID, delay: WebtoonConstants.layoutReadyDelay)
        }
      }

      private func captureOffsetWithinPage(_ pageID: ReaderPageID?) -> CGFloat? {
        guard let pageID else { return nil }
        guard let cv = collectionView, let sv = scrollView else { return nil }
        return WebtoonScrollOffset.captureOffsetWithinPage(
          pageID: pageID,
          currentTopY: sv.contentView.bounds.origin.y,
          itemIndexForPage: { [weak self] pageID in
            self?.itemIndex(forPageID: pageID)
          },
          frameForItemIndex: { itemIndex in
            cv.layoutAttributesForItem(at: IndexPath(item: itemIndex, section: 0))?.frame
          }
        )
      }

      @discardableResult
      private func restoreOffsetWithinPage(_ offsetWithinPage: CGFloat, for pageID: ReaderPageID) -> Bool {
        guard let cv = collectionView, let sv = scrollView else { return false }
        guard
          let targetY = WebtoonScrollOffset.targetTopYForPage(
            pageID: pageID,
            offsetWithinPage: offsetWithinPage,
            itemIndexForPage: { [weak self] pageID in
              self?.itemIndex(forPageID: pageID)
            },
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
        let preCapturedOffset = scrollEngine.pendingReloadPreCapturedOffset
        scrollEngine.pendingReloadPreCapturedOffset = nil
        let latestCapturedOffset = captureOffsetWithinPage(pendingPageID) ?? preCapturedOffset

        handleDataReload(
          collectionView: collectionView,
          currentPageID: pendingPageID,
          preCapturedOffset: latestCapturedOffset
        )
        updateCurrentPage()
      }

      private func cancelDeferredMaintenance() {
        deferredReloadWorkItem?.cancel()
        deferredReloadWorkItem = nil
        deferredCleanupWorkItem?.cancel()
        deferredCleanupWorkItem = nil
      }

      private func scheduleDeferredPendingReloadIfNeeded() {
        guard scrollEngine.pendingReloadCurrentPageID != nil else { return }
        deferredReloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
          guard let self else { return }
          self.deferredReloadWorkItem = nil
          guard !self.isScrollInteractionActive else { return }
          self.applyPendingReloadIfNeeded()
        }
        deferredReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(
          deadline: .now() + WebtoonConstants.postScrollReloadDelay,
          execute: workItem
        )
      }

      private func scheduleDeferredCleanupIfNeeded() {
        deferredCleanupWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
          guard let self else { return }
          self.deferredCleanupWorkItem = nil
          guard !self.isScrollInteractionActive else { return }
          self.viewModel?.cleanupDistantImagesAroundCurrentPage()
        }
        deferredCleanupWorkItem = workItem
        DispatchQueue.main.asyncAfter(
          deadline: .now() + WebtoonConstants.postScrollCleanupDelay,
          execute: workItem
        )
      }

      private func finalizeProgrammaticScroll() {
        isProgrammaticScrolling = false
        applyPendingMeasuredLayoutUpdatesIfNeeded()
        updateCurrentPage()
        scheduleDeferredPendingReloadIfNeeded()
        scheduleDeferredCleanupIfNeeded()
      }

      private func finalizeScrollInteraction() {
        isUserScrolling = false
        applyPendingMeasuredLayoutUpdatesIfNeeded()
        updateCurrentPage()
        scheduleDeferredPendingReloadIfNeeded()
        scheduleDeferredCleanupIfNeeded()
      }

      func scrollToPage(_ pageID: ReaderPageID, animated: Bool) {
        guard let cv = collectionView else { return }
        guard let itemIndex = itemIndex(forPageID: pageID) else { return }
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
          let cv = collectionView,
          let itemIndex = itemIndex(forPageID: pageID),
          cv.bounds.width > 0
        else {
          if !scrollEngine.hasScrolledToInitialPage {
            requestInitialScroll(pageID, delay: WebtoonConstants.initialScrollRetryDelay)
          }
          return
        }
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
            previousBook: viewModel?.endPagePreviousBook(forSegmentBookId: segmentBookId),
            nextBook: viewModel?.nextBook(forSegmentBookId: segmentBookId),
            readListContext: readListContext,
            onDismiss: onDismiss
          )
          return cell
        case .page(let pageID):
          let page = viewModel?.page(for: pageID)
          ensureMeasuredHeightProbe(for: pageID, page: page)

          let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("WebtoonPageCell"),
            for: indexPath
          )
          guard let cell = item as? WebtoonPageCell else {
            assertionFailure("Failed to make WebtoonPageCell")
            return item
          }
          cell.readerBackground = readerBackground
          let displayImage = displayImageIfReady(
            viewModel?.preloadedImage(for: pageID),
            for: pageID,
            page: page
          )
          let pageLabel =
            viewModel?.displayPageNumber(for: pageID).map(String.init)
            ?? String(pageID.pageNumber)

          cell.configure(
            pageLabel: pageLabel,
            image: displayImage,
            showPageNumber: showPageNumber
          )

          if displayImage == nil, hasKnownHeight(for: pageID, page: page) {
            Task { @MainActor [weak self] in
              await self?.loadImage(for: pageID)
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
          guard let page = viewModel?.page(for: pageID) else {
            return NSSize(width: pageWidth, height: WebtoonConstants.measuringPlaceholderHeight)
          }
          if let preloadedImage = viewModel?.preloadedImage(for: pageID),
            let pixelSize = webtoonPixelSize(from: preloadedImage)
          {
            _ = heightCache.updateHeight(for: pageID, pixelSize: pixelSize, pageWidth: pageWidth)
          }
          if !hasKnownHeight(for: pageID, page: page) {
            return NSSize(width: pageWidth, height: WebtoonConstants.measuringPlaceholderHeight)
          }
          let height = heightCache.height(for: pageID, page: page, pageWidth: pageWidth)
          let scale = collectionView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
          let alignedHeight = scale > 0 ? ceil(height * scale) / scale : height
          return NSSize(width: pageWidth, height: alignedHeight)
        }
      }

      // MARK: - Scroll

      @objc func scrollViewDidScroll(_ notification: Notification) {
        if !isProgrammaticScrolling {
          if !isUserScrolling {
            cancelDeferredMaintenance()
          }
          isUserScrolling = true
        }
        lastScrollTime = Date().timeIntervalSinceReferenceDate
        updateCurrentPage(commitToViewModel: false)
      }

      @objc func scrollViewDidEndScroll(_ notification: Notification) {
        finalizeScrollInteraction()
      }

      private func updateCurrentPage(commitToViewModel: Bool = true) {
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
          let resolvedPageID = scrollEngine.resolvedPageID(
            forItemIndex: newCurrentItemIndex,
            viewModel: viewModel
          )
        else {
          return
        }

        if scrollEngine.currentPageID != resolvedPageID {
          scrollEngine.currentPageID = resolvedPageID
        }
        if commitToViewModel, viewModel?.currentReaderPage?.id != resolvedPageID {
          viewModel?.updateCurrentPosition(pageID: resolvedPageID)
        }
      }

      // MARK: - Image Loading

      @MainActor
      func loadImage(for pageID: ReaderPageID) async {
        guard let vm = viewModel else { return }

        if let preloadedImage = vm.preloadedImage(for: pageID) {
          if let pixelSize = webtoonPixelSize(from: preloadedImage) {
            applyMeasuredHeightIfNeeded(for: pageID, pixelSize: pixelSize)
          }
          if let page = vm.page(for: pageID),
            hasKnownHeight(for: pageID, page: page)
          {
            pageCell(for: pageID)?.setImage(preloadedImage)
          }
          return
        }

        if let image = await vm.preloadImage(for: pageID) {
          if let pixelSize = webtoonPixelSize(from: image) {
            applyMeasuredHeightIfNeeded(for: pageID, pixelSize: pixelSize)
          }
          if let page = vm.page(for: pageID),
            hasKnownHeight(for: pageID, page: page)
          {
            pageCell(for: pageID)?.setImage(image)
          }
        }
      }

      private func pageCell(for pageID: ReaderPageID) -> WebtoonPageCell? {
        guard let cv = collectionView else { return nil }
        guard let itemIndex = itemIndex(forPageID: pageID) else { return nil }
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

      func scrollWebtoon(_ direction: WebtoonScrollDirection) {
        guard let sv = scrollView else { return }

        let screenHeight = sv.contentView.bounds.height
        guard screenHeight > 0 else { return }

        switch direction {
        case .up:
          scrollUp(screenHeight)
        case .down:
          scrollDown(screenHeight)
        }
      }

      private func scrollToOffsetIfNeeded(_ targetY: CGFloat, in scrollView: NSScrollView) {
        let clipView = scrollView.contentView
        let currentY = clipView.bounds.origin.y
        guard abs(targetY - currentY) > WebtoonConstants.offsetEpsilon else {
          isProgrammaticScrolling = false
          updateCurrentPage()
          return
        }

        cancelDeferredMaintenance()
        preheatPages(at: targetY)

        isProgrammaticScrolling = true
        if AppConfig.animateTapTurns {
          NSAnimationContext.runAnimationGroup(
            { context in
              context.duration = WebtoonConstants.scrollAnimationDuration
              context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
              context.allowsImplicitAnimation = true
              clipView.animator().scroll(to: NSPoint(x: 0, y: targetY))
            },
            completionHandler: { [weak self, weak scrollView, weak clipView] in
              Task { @MainActor [weak self, weak scrollView, weak clipView] in
                self?.finalizeProgrammaticScroll()
                guard let scrollView, let clipView else { return }
                scrollView.reflectScrolledClipView(clipView)
              }
            }
          )
        } else {
          clipView.scroll(to: NSPoint(x: 0, y: targetY))
          finalizeProgrammaticScroll()
          scrollView.reflectScrolledClipView(clipView)
        }
      }

      private func preheatPages(at targetOffset: CGFloat) {
        guard let cv = collectionView, let sv = scrollView else { return }
        let centerY = targetOffset + sv.contentView.bounds.height / 2
        let centerPoint = NSPoint(x: cv.bounds.width / 2, y: centerY)
        guard let indexPath = cv.indexPathForItem(at: centerPoint),
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
        Task(priority: .utility) { @MainActor [weak self] in
          guard let viewModel = self?.viewModel else { return }
          for pageID in pageIDs {
            _ = await viewModel.preloadImage(for: pageID)
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
        onZoomRequest?(result.pageID, result.anchor)
      }

      private func pageIndexAndAnchor(for location: NSPoint) -> (pageID: ReaderPageID, anchor: CGPoint)? {
        guard let cv = collectionView else { return nil }

        if let indexPath = cv.indexPathForItem(at: location),
          let pageID = scrollEngine.resolvedPageID(
            forItemIndex: indexPath.item,
            viewModel: viewModel
          )
        {
          if let item = cv.item(at: indexPath) {
            let local = item.view.convert(location, from: cv)
            return (
              pageID,
              normalizedAnchor(in: item.view.bounds, location: local, isFlipped: item.view.isFlipped)
            )
          }
          if let attributes = cv.layoutAttributesForItem(at: indexPath) {
            return (
              pageID,
              normalizedAnchor(in: attributes.frame, location: location, isFlipped: cv.isFlipped)
            )
          }
        }

        guard let fallbackPageID = scrollEngine.currentPageID else { return nil }
        guard let itemIndex = itemIndex(forPageID: fallbackPageID) else { return nil }
        let fallbackIndexPath = IndexPath(item: itemIndex, section: 0)
        if let item = cv.item(at: fallbackIndexPath) {
          let local = item.view.convert(location, from: cv)
          return (
            fallbackPageID,
            normalizedAnchor(in: item.view.bounds, location: local, isFlipped: item.view.isFlipped)
          )
        }
        if let attributes = cv.layoutAttributesForItem(at: fallbackIndexPath) {
          return (
            fallbackPageID,
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
