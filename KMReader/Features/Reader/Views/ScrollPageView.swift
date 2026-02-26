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
  let onPlayAnimatedPage: ((Int) -> Void)?
  let onScrollActivityChange: ((Bool) -> Void)?

  private let logger = AppLogger(.reader)

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?
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
    onPlayAnimatedPage: ((Int) -> Void)? = nil,
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
        .onChange(of: viewModel.targetPageIndex) { _, newTarget in
          if let newTarget = newTarget {
            handleTargetPageChange(newTarget, proxy: proxy)
            // Reset targetPageIndex to allow consecutive taps to the same target if we swiped away
            Task { @MainActor in
              viewModel.targetPageIndex = nil
            }
          }
        }
        .onChange(of: viewModel.targetViewItemIndex) { _, newTarget in
          if let newTarget = newTarget {
            handleTargetViewItemChange(newTarget, proxy: proxy)
            // Reset targetViewItemIndex to allow consecutive taps
            Task { @MainActor in
              viewModel.targetViewItemIndex = nil
            }
          }
        }
        .onChange(of: viewModel.viewItems.count) { _, _ in
          guard hasSyncedInitialScroll else { return }
          let target = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
          if scrollPosition != target {
            scrollPosition = target
            proxy.scrollTo(target, anchor: .center)
          }
          preloadVisiblePages(forViewItemIndex: target)
          #if os(tvOS)
            updateContentAnchorFocus()
          #endif
        }
        .onChange(of: scrollPosition) { _, newPosition in
          if let newPosition, newPosition < viewModel.viewItems.count {
            viewModel.updateCurrentPosition(viewItemIndex: newPosition)
            preloadVisiblePages(forViewItemIndex: newPosition)

            // Clear targetPageIndex if the user manually scrolled
            if viewModel.targetPageIndex != nil {
              viewModel.targetPageIndex = nil
            }
            if viewModel.targetViewItemIndex != nil {
              viewModel.targetViewItemIndex = nil
            }
          }
        }
        .onChange(of: showingControls) { _, _ in
          #if os(tvOS)
            logger.debug(
              "📺 showingControls changed in ScrollPageView: \(showingControls), currentViewItemIndex=\(viewModel.currentViewItemIndex)"
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
        .onChange(of: viewModel.currentViewItemIndex) { _, _ in
          #if os(tvOS)
            logger.debug("📺 currentViewItemIndex changed: \(viewModel.currentViewItemIndex)")
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
    ForEach(Array(viewModel.viewItems.enumerated()), id: \.offset) { offset, item in
      Group {
        switch item {
        case .end(let bookId):
          EndPageView(
            previousBook: viewModel.currentBook(forSegmentBookId: bookId),
            nextBook: viewModel.nextBook(forSegmentBookId: bookId),
            readListContext: readListContext,
            onDismiss: onDismiss,
            readingDirection: readingDirection
          )
        case .dual(let first, let second):
          if let firstPageIndex = viewModel.pageIndex(for: first),
            let secondPageIndex = viewModel.pageIndex(for: second)
          {
            DualPageImageView(
              viewModel: viewModel,
              firstPageIndex: firstPageIndex,
              secondPageIndex: secondPageIndex,
              isPlaybackActive: offset == viewModel.currentViewItemIndex,
              screenSize: geometry.size,
              renderConfig: renderConfig,
              readingDirection: readingDirection,
              onPlayAnimatedPage: onPlayAnimatedPage
            )
          }
        case .page(let id):
          if let pageIndex = viewModel.pageIndex(for: id) {
            SinglePageImageView(
              viewModel: viewModel,
              pageIndex: pageIndex,
              isPlaybackActive: offset == viewModel.currentViewItemIndex,
              screenSize: geometry.size,
              renderConfig: renderConfig,
              readingDirection: readingDirection,
              onPlayAnimatedPage: onPlayAnimatedPage
            )
          }
        case .split(let id, let part):
          if let pageIndex = viewModel.pageIndex(for: id) {
            let isLeftHalf = viewModel.isLeftSplitHalf(
              part: part,
              readingDirection: readingDirection,
              splitWidePageMode: splitWidePageMode
            )
            SplitWidePageImageView(
              viewModel: viewModel,
              pageIndex: pageIndex,
              isLeftHalf: isLeftHalf,
              isPlaybackActive: offset == viewModel.currentViewItemIndex,
              screenSize: geometry.size,
              renderConfig: renderConfig,
              readingDirection: readingDirection,
              onPlayAnimatedPage: onPlayAnimatedPage
            )
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .id(offset)
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
    guard viewModel.currentPageIndex >= 0 else { return }
    guard viewModel.hasPages else { return }

    let target = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .center)
      viewModel.updateCurrentPosition(viewItemIndex: target)
      hasSyncedInitialScroll = true
      preloadVisiblePages(forViewItemIndex: target)
    }
  }

  private func syncCurrentPositionIfNeeded(target: Int) {
    guard target >= 0 else { return }
    guard target < viewModel.viewItems.count else { return }
    if viewModel.currentViewItemIndex != target {
      viewModel.updateCurrentPosition(viewItemIndex: target)
    }
  }

  private func handleTargetPageChange(_ newTarget: Int?, proxy: ScrollViewProxy) {
    guard let newTarget = newTarget else { return }
    guard hasSyncedInitialScroll else { return }
    guard newTarget >= 0 else { return }
    guard viewModel.hasPages else { return }

    let targetScrollPosition = viewModel.viewItemIndex(forPageIndex: newTarget)

    if scrollPosition != targetScrollPosition {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: .center)
      }
    }

    syncCurrentPositionIfNeeded(target: targetScrollPosition)
    preloadVisiblePages(forViewItemIndex: targetScrollPosition)

    // Progress update is handled by parent on currentPageIndex change.
    Task(priority: .utility) {
      await viewModel.preloadPages()
    }
  }

  private func handleTargetViewItemChange(_ newTarget: Int, proxy: ScrollViewProxy) {
    guard hasSyncedInitialScroll else { return }
    guard newTarget >= 0 else { return }
    guard viewModel.hasPages else { return }
    guard newTarget < viewModel.viewItems.count else { return }

    let targetScrollPosition = newTarget

    if scrollPosition != targetScrollPosition {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: .center)
      }
    }

    syncCurrentPositionIfNeeded(target: targetScrollPosition)
    preloadVisiblePages(forViewItemIndex: targetScrollPosition)

    // Progress update is handled by parent on currentPageIndex change.
    Task(priority: .utility) {
      await viewModel.preloadPages()
    }
  }

  private func preloadVisiblePages(forViewItemIndex viewItemIndex: Int) {
    guard let item = viewModel.viewItem(at: viewItemIndex) else { return }

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
