//
// ScrollPageView.swift
//
//

import SwiftUI

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
  let onPlayAnimatedPage: ((ReaderPageID) -> Void)?
  let onScrollActivityChange: ((Bool) -> Void)?

  private let logger = AppLogger(.reader)

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: ReaderViewItem?
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
    onPlayAnimatedPage: ((ReaderPageID) -> Void)? = nil,
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
    self.onPlayAnimatedPage = onPlayAnimatedPage
    self.onScrollActivityChange = onScrollActivityChange
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
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
          synchronizeInitialScrollIfNeeded(proxy: proxy)
          #if os(tvOS)
            updateContentAnchorFocus()
          #endif
        }
        .onChange(of: viewModel.navigationTarget) { _, newTarget in
          if let newTarget {
            handleNavigationChange(newTarget, proxy: proxy)
            Task { @MainActor in
              viewModel.clearNavigationTarget()
            }
          }
        }
        .onChange(of: viewModel.viewItems) { _, _ in
          guard hasSyncedInitialScroll else { return }
          guard let currentItem = viewModel.currentViewItem() else { return }
          syncScrollPosition(to: currentItem, proxy: proxy, animated: false)
          #if os(tvOS)
            updateContentAnchorFocus()
          #endif
        }
        .onChange(of: scrollPosition) { _, newPosition in
          if let newPosition {
            viewModel.updateCurrentPosition(viewItem: newPosition)
            preloadVisiblePages(for: newPosition)
            if viewModel.navigationTarget != nil {
              viewModel.clearNavigationTarget()
            }
          }
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
    }
  }

  @ViewBuilder
  private func scrollViewContent(geometry: GeometryProxy, isScrollDisabled: Bool) -> some View {
    ScrollView(mode.isVertical ? .vertical : .horizontal) {
      if mode.isVertical {
        LazyVStack(spacing: 0) {
          viewItemContent(geometry: geometry)
        }
        .scrollTargetLayout()
      } else {
        LazyHStack(spacing: 0) {
          viewItemContent(geometry: geometry)
        }
        .scrollTargetLayout()
      }
    }
    .scrollIndicators(.never)
    .scrollDisabled(isScrollDisabled)
    .environment(\.layoutDirection, mode.isRTL ? .rightToLeft : .leftToRight)
  }

  @ViewBuilder
  private func viewItemContent(geometry: GeometryProxy) -> some View {
    ForEach(viewModel.viewItems, id: \.self) { item in
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
            splitWidePageMode: splitWidePageMode,
            onPlayAnimatedPage: onPlayAnimatedPage
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

    DispatchQueue.main.async {
      syncScrollPosition(to: currentItem, proxy: proxy, animated: false)
      hasSyncedInitialScroll = true
    }
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
    syncScrollPosition(to: targetItem, proxy: proxy, animated: true)

    Task(priority: .utility) {
      await viewModel.preloadPages()
    }
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
