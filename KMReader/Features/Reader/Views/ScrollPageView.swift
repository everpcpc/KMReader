//
// ScrollPageView.swift
//
//

import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct ScrollPageView: View {
  let mode: PageViewMode
  let readingDirection: ReadingDirection
  let splitWidePageMode: SplitWidePageMode
  let renderConfig: ReaderRenderConfig
  let showingControls: Bool
  @Bindable var viewModel: ReaderViewModel
  let readListContext: ReaderReadListContext?
  let onDismiss: () -> Void
  let toggleControls: () -> Void
  let onScrollActivityChange: ((Bool) -> Void)?

  private let logger = AppLogger(.reader)

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.3

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: ReaderViewItem?
  @State private var renderedViewItems: [ReaderViewItem] = []
  @State private var pendingRenderedViewItems: [ReaderViewItem]?
  @State private var deferredAnchorItem: ReaderViewItem?
  @State private var isUserInteractingWithScroll = false
  #if os(tvOS)
    @FocusState private var isContentAnchorFocused: Bool
  #endif

  private var shouldDisableScrollInteraction: Bool {
    #if os(tvOS)
      true
    #else
      viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil
    #endif
  }

  private var activeRenderedItems: [ReaderViewItem] {
    renderedViewItems.isEmpty ? viewModel.viewItems : renderedViewItems
  }

  init(
    mode: PageViewMode,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode,
    renderConfig: ReaderRenderConfig,
    showingControls: Bool,
    viewModel: ReaderViewModel,
    readListContext: ReaderReadListContext?,
    onDismiss: @escaping () -> Void,
    toggleControls: @escaping () -> Void,
    onScrollActivityChange: ((Bool) -> Void)? = nil
  ) {
    self.mode = mode
    self.readingDirection = readingDirection
    self.splitWidePageMode = splitWidePageMode
    self.renderConfig = renderConfig
    self.showingControls = showingControls
    self.viewModel = viewModel
    self.readListContext = readListContext
    self.onDismiss = onDismiss
    self.toggleControls = toggleControls
    self.onScrollActivityChange = onScrollActivityChange
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
        configuredScrollContainer(geometry: geometry, proxy: proxy)
      }
    }
  }

  @ViewBuilder
  private func configuredScrollContainer(
    geometry: GeometryProxy,
    proxy: ScrollViewProxy
  ) -> some View {
    scrollViewContent(
      geometry: geometry,
      isScrollDisabled: shouldDisableScrollInteraction
    )
    .frame(width: geometry.size.width, height: geometry.size.height)
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $scrollPosition)
    .overlay(alignment: .topLeading) {
      contentAnchor
    }
    #if os(tvOS)
      .focusable(false)
    #endif
    .onAppear {
      if renderedViewItems.isEmpty {
        renderedViewItems = viewModel.viewItems
      }
      synchronizeInitialScrollIfNeeded(proxy: proxy)
      #if os(tvOS)
        updateContentAnchorFocus()
      #endif
    }
    .onDisappear {
      setScrollInteractionActive(false)
      pendingRenderedViewItems = nil
      deferredAnchorItem = nil
    }
    .onChange(of: viewModel.navigationTarget) { _, newTarget in
      guard let newTarget else { return }
      handleNavigationChange(newTarget, proxy: proxy)
      Task { @MainActor in
        viewModel.clearNavigationTarget()
      }
    }
    .onChange(of: viewModel.viewItems) { _, newItems in
      handleViewItemsChange(newItems, proxy: proxy)
    }
    .onChange(of: isUserInteractingWithScroll) { _, isInteracting in
      guard !isInteracting else { return }
      applyPendingRenderedItemsIfNeeded(proxy: proxy)
    }
    .onChange(of: scrollPosition) { _, newPosition in
      handleScrollPositionChange(newPosition)
    }
    .onChange(of: showingControls) { _, _ in
      #if os(tvOS)
        logger.debug(
          "📺 showingControls changed in ScrollPageView: \(showingControls), currentViewItem=\(String(describing: viewModel.currentViewItem()))"
        )
        if showingControls {
          isContentAnchorFocused = false
        } else {
          DispatchQueue.main.async {
            updateContentAnchorFocus()
          }
        }
      #endif
    }
    .onChange(of: viewModel.currentViewItem()) { _, _ in
      #if os(tvOS)
        logger.debug("📺 currentViewItem changed: \(String(describing: viewModel.currentViewItem()))")
        updateContentAnchorFocus()
      #endif
    }
    #if os(tvOS)
      .onChange(of: isContentAnchorFocused) { _, newValue in
        logger.debug(
          "📺 contentAnchor focus changed: \(newValue), showingControls=\(showingControls)"
        )
        if !newValue && !showingControls {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            updateContentAnchorFocus()
          }
        }
      }
    #endif
  }

  private func handleViewItemsChange(_ newItems: [ReaderViewItem], proxy: ScrollViewProxy) {
    if renderedViewItems.isEmpty {
      renderedViewItems = newItems
    }

    guard hasSyncedInitialScroll else {
      renderedViewItems = newItems
      return
    }

    let anchor = viewModel.currentViewItem() ?? scrollPosition
    guard let anchor else {
      renderedViewItems = newItems
      return
    }

    if isUserInteractingWithScroll {
      pendingRenderedViewItems = newItems
      deferredAnchorItem = anchor
    } else {
      applyRenderedItemsSnapshot(newItems, anchor: anchor, proxy: proxy)
    }

    #if os(tvOS)
      updateContentAnchorFocus()
    #endif
  }

  private func applyPendingRenderedItemsIfNeeded(proxy: ScrollViewProxy) {
    guard let pendingRenderedViewItems else { return }
    self.pendingRenderedViewItems = nil

    let anchor = deferredAnchorItem ?? viewModel.currentViewItem() ?? scrollPosition
    deferredAnchorItem = nil

    guard let anchor else {
      renderedViewItems = pendingRenderedViewItems
      return
    }

    applyRenderedItemsSnapshot(pendingRenderedViewItems, anchor: anchor, proxy: proxy)
  }

  #if os(iOS)
    private var scrollActivityBridge: some View {
      ScrollViewActivityBridge { isActive in
        setScrollInteractionActive(isActive)
      }
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  #endif

  @ViewBuilder
  private func scrollViewContent(geometry: GeometryProxy, isScrollDisabled: Bool) -> some View {
    ScrollView(mode.isVertical ? .vertical : .horizontal) {
      if mode.isVertical {
        LazyVStack(spacing: 0) {
          viewItemContent(geometry: geometry)
        }
        .scrollTargetLayout()
        #if os(iOS)
          .background(scrollActivityBridge)
        #endif
      } else {
        LazyHStack(spacing: 0) {
          viewItemContent(geometry: geometry)
        }
        .scrollTargetLayout()
        #if os(iOS)
          .background(scrollActivityBridge)
        #endif
      }
    }
    .scrollIndicators(.never)
    .scrollDisabled(isScrollDisabled)
    .environment(\.layoutDirection, mode.isRTL ? .rightToLeft : .leftToRight)
  }

  @ViewBuilder
  private func viewItemContent(geometry: GeometryProxy) -> some View {
    ForEach(activeRenderedItems, id: \.self) { item in
      Group {
        if case .end(let id) = item {
          EndPageView(
            previousBook: viewModel.currentBook(forSegmentBookId: id.bookId),
            nextBook: viewModel.nextBook(forSegmentBookId: id.bookId),
            readListContext: readListContext,
            onDismiss: onDismiss,
            readingDirection: readingDirection
          )
        } else {
          ReaderViewItemImageView(
            viewModel: viewModel,
            item: item,
            isPlaybackActive: item == viewModel.currentViewItem(),
            screenSize: geometry.size,
            renderConfig: renderConfig,
            readingDirection: readingDirection,
            splitWidePageMode: splitWidePageMode
          )
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .id(item)
      .readerPageScrollTransition()
    }
  }

  @ViewBuilder
  private var contentAnchor: some View {
    #if os(tvOS)
      Button {
        logger.debug("📺 contentAnchor select: toggle controls")
        toggleControls()
      } label: {
        Color.clear
          .frame(width: 1, height: 1)
      }
      .buttonStyle(.plain)
      .focusable(!showingControls)
      .focused($isContentAnchorFocused)
      .opacity(0.001)
    #else
      EmptyView()
    #endif
  }

  #if os(tvOS)
    private func updateContentAnchorFocus() {
      guard !showingControls else {
        logger.debug("📺 updateContentAnchorFocus -> blur (controls visible)")
        isContentAnchorFocused = false
        return
      }

      logger.debug("📺 updateContentAnchorFocus -> focus content anchor")
      isContentAnchorFocused = true
    }
  #endif

  // MARK: - Scroll Synchronization

  private func synchronizeInitialScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !hasSyncedInitialScroll else { return }
    guard viewModel.hasPages else { return }
    guard let currentItem = viewModel.currentViewItem() else { return }

    renderedViewItems = viewModel.viewItems

    DispatchQueue.main.async {
      syncScrollPosition(to: currentItem, proxy: proxy, animated: false)
      hasSyncedInitialScroll = true
    }
  }

  private func setScrollInteractionActive(_ isActive: Bool) {
    guard isUserInteractingWithScroll != isActive else { return }
    isUserInteractingWithScroll = isActive
    onScrollActivityChange?(isActive)
  }

  private func syncCurrentPositionIfNeeded(targetItem: ReaderViewItem) {
    if viewModel.currentViewItem() != targetItem {
      viewModel.updateCurrentPosition(viewItem: targetItem)
    }
  }

  private func syncScrollPosition(
    to targetItem: ReaderViewItem,
    proxy: ScrollViewProxy,
    animated: Bool
  ) {
    guard activeRenderedItems.contains(targetItem) else { return }

    if scrollPosition != targetItem {
      let animation: Animation? =
        animated && tapPageTransitionDuration > 0
        ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetItem
        proxy.scrollTo(targetItem, anchor: .center)
      }
    }

    syncCurrentPositionIfNeeded(targetItem: targetItem)
    preloadVisiblePages(for: targetItem)
  }

  private func handleNavigationChange(_ newTarget: ReaderViewItem, proxy: ScrollViewProxy) {
    guard hasSyncedInitialScroll else { return }
    guard viewModel.hasPages else { return }
    guard let targetItem = viewModel.resolvedViewItem(for: newTarget) else { return }

    pendingRenderedViewItems = nil
    deferredAnchorItem = nil

    if activeRenderedItems.contains(targetItem) {
      syncScrollPosition(to: targetItem, proxy: proxy, animated: true)
    } else {
      applyRenderedItemsSnapshot(viewModel.viewItems, anchor: targetItem, proxy: proxy)
    }

    Task(priority: .utility) {
      await viewModel.preloadPages()
    }
  }

  private func handleScrollPositionChange(_ newPosition: ReaderViewItem?) {
    guard let newPosition else { return }
    guard activeRenderedItems.contains(newPosition) else {
      logger.warning("⚠️ Ignored scrollPosition update not present in rendered snapshot")
      return
    }

    syncCurrentPositionIfNeeded(targetItem: newPosition)
    preloadVisiblePages(for: newPosition)
    if viewModel.navigationTarget != nil {
      viewModel.clearNavigationTarget()
    }
  }

  private func applyRenderedItemsSnapshot(
    _ snapshot: [ReaderViewItem],
    anchor: ReaderViewItem,
    proxy: ScrollViewProxy
  ) {
    renderedViewItems = snapshot

    guard let resolvedAnchor = resolveAnchorInSnapshot(anchor, snapshot: snapshot) else {
      return
    }

    syncScrollPosition(to: resolvedAnchor, proxy: proxy, animated: false)
  }

  private func resolveAnchorInSnapshot(
    _ anchor: ReaderViewItem,
    snapshot: [ReaderViewItem]
  ) -> ReaderViewItem? {
    if snapshot.contains(anchor) {
      return anchor
    }

    if let pageMatch = snapshot.first(where: { $0.pageID == anchor.pageID }) {
      return pageMatch
    }

    return snapshot.first
  }

  private func preloadVisiblePages(for item: ReaderViewItem) {
    let visiblePageIndices: [Int]
    switch item {
    case .page(let id):
      visiblePageIndices = [viewModel.pageIndex(for: id)].compactMap { $0 }
    case .split(let id, _):
      visiblePageIndices = [viewModel.pageIndex(for: id)].compactMap { $0 }
    case .dual(let first, let second):
      visiblePageIndices = [viewModel.pageIndex(for: first), viewModel.pageIndex(for: second)].compactMap { $0 }
    case .end:
      visiblePageIndices = []
    }

    guard !visiblePageIndices.isEmpty else { return }

    Task(priority: .userInitiated) {
      for pageIndex in visiblePageIndices {
        _ = await viewModel.preloadImageForPage(at: pageIndex)
      }
    }
  }
}

#if os(iOS)
  private struct ScrollViewActivityBridge: UIViewRepresentable {
    let onActivityChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onActivityChange: onActivityChange)
    }

    func makeUIView(context: Context) -> BridgeView {
      let view = BridgeView()
      view.coordinator = context.coordinator
      return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
      context.coordinator.onActivityChange = onActivityChange
      uiView.coordinator = context.coordinator
      context.coordinator.attachIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: BridgeView, coordinator: Coordinator) {
      coordinator.detach()
    }

    final class BridgeView: UIView {
      weak var coordinator: Coordinator?

      override func didMoveToWindow() {
        super.didMoveToWindow()
        coordinator?.attachIfNeeded(from: self)
      }

      override func layoutSubviews() {
        super.layoutSubviews()
        coordinator?.attachIfNeeded(from: self)
      }
    }

    final class Coordinator: NSObject {
      var onActivityChange: (Bool) -> Void

      private weak var scrollView: UIScrollView?
      private var displayLink: CADisplayLink?
      private var stableFrameCount = 0
      private var isActive = false

      init(onActivityChange: @escaping (Bool) -> Void) {
        self.onActivityChange = onActivityChange
      }

      func attachIfNeeded(from view: UIView) {
        guard let targetScrollView = findScrollView(from: view) else { return }
        guard scrollView !== targetScrollView else { return }

        detach()

        scrollView = targetScrollView
        targetScrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))

        if targetScrollView.isTracking || targetScrollView.isDragging || targetScrollView.isDecelerating {
          setActive(true)
          startDisplayLink()
        } else {
          setActive(false)
        }
      }

      func detach() {
        if let scrollView {
          scrollView.panGestureRecognizer.removeTarget(self, action: #selector(handlePanGesture(_:)))
        }
        stopDisplayLink()
        self.scrollView = nil
        setActive(false)
      }

      @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
          stableFrameCount = 0
          setActive(true)
          startDisplayLink()
        case .ended, .cancelled, .failed:
          startDisplayLink()
        default:
          break
        }
      }

      @objc private func pollScrollState() {
        guard let scrollView else {
          stopDisplayLink()
          setActive(false)
          return
        }

        let moving = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating
        if moving {
          stableFrameCount = 0
          setActive(true)
          return
        }

        stableFrameCount += 1
        if stableFrameCount >= 2 {
          stopDisplayLink()
          setActive(false)
        }
      }

      private func startDisplayLink() {
        guard displayLink == nil else { return }
        stableFrameCount = 0
        let link = CADisplayLink(target: self, selector: #selector(pollScrollState))
        link.add(to: .main, forMode: .common)
        displayLink = link
      }

      private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        stableFrameCount = 0
      }

      private func setActive(_ newValue: Bool) {
        guard isActive != newValue else { return }
        isActive = newValue
        onActivityChange(newValue)
      }

      private func findScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let candidate = current {
          if let scrollView = candidate as? UIScrollView {
            return scrollView
          }
          current = candidate.superview
        }
        return nil
      }
    }
  }
#endif
