//
//  ScrollPageView.swift
//  Komga
//

import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct ScrollPageView: View {
  let mode: PageViewMode
  let readingDirection: ReadingDirection
  let splitWidePageMode: SplitWidePageMode
  let showingControls: Bool
  @Bindable var viewModel: ReaderViewModel
  let previousBook: Book?
  let nextBook: Book?
  let readList: ReadList?
  let onDismiss: () -> Void
  let onPreviousBook: (String) -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void
  let onPlayAnimatedPage: ((Int) -> Void)?
  let onScrollActivityChange: ((Bool) -> Void)?
  let onBoundaryPanUpdate: ((CGFloat) -> Void)?

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  private let logger = AppLogger(.reader)

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?
  #if os(iOS)
    @State private var boundaryDragOffset: CGFloat = 0
    @State private var hasTriggeredBoundaryHaptic = false
    private let boundarySwipeThreshold: CGFloat = 120
  #endif
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
    showingControls: Bool,
    viewModel: ReaderViewModel,
    previousBook: Book?,
    nextBook: Book?,
    readList: ReadList?,
    onDismiss: @escaping () -> Void,
    onPreviousBook: @escaping (String) -> Void,
    onNextBook: @escaping (String) -> Void,
    goToNextPage: @escaping () -> Void,
    goToPreviousPage: @escaping () -> Void,
    toggleControls: @escaping () -> Void,
    onPlayAnimatedPage: ((Int) -> Void)? = nil,
    onScrollActivityChange: ((Bool) -> Void)? = nil,
    onBoundaryPanUpdate: ((CGFloat) -> Void)? = nil
  ) {
    self.mode = mode
    self.readingDirection = readingDirection
    self.splitWidePageMode = splitWidePageMode
    self.showingControls = showingControls
    self.viewModel = viewModel
    self.previousBook = previousBook
    self.nextBook = nextBook
    self.readList = readList
    self.onDismiss = onDismiss
    self.onPreviousBook = onPreviousBook
    self.onNextBook = onNextBook
    self.goToNextPage = goToNextPage
    self.goToPreviousPage = goToPreviousPage
    self.toggleControls = toggleControls
    self.onPlayAnimatedPage = onPlayAnimatedPage
    self.onScrollActivityChange = onScrollActivityChange
    self.onBoundaryPanUpdate = onBoundaryPanUpdate
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
        #if os(iOS)
          .simultaneousGesture(boundarySwipeGesture)
        #endif
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
          #if os(tvOS)
            updateContentAnchorFocus()
          #endif
        }
        .onChange(of: scrollPosition) { _, newPosition in
          if let newPosition, newPosition < viewModel.viewItems.count {
            viewModel.updateCurrentPosition(viewItemIndex: newPosition)

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
          #if os(iOS)
            resetBoundarySwipeState(animated: false)
          #endif
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

  #if os(iOS)
    private enum BoundaryNavigationAction {
      case openPrevious(String)
      case openNext(String)
    }

    private var supportsBoundarySwipe: Bool {
      readingDirection != .webtoon
    }

    private var isAtFirstBoundary: Bool {
      viewModel.currentViewItemIndex == 0
    }

    private var isAtEndBoundary: Bool {
      guard !viewModel.viewItems.isEmpty else { return false }
      return viewModel.currentViewItemIndex == viewModel.viewItems.count - 1
    }

    private var hasBoundarySwipeContext: Bool {
      (isAtFirstBoundary && previousBook != nil) || (isAtEndBoundary && nextBook != nil)
    }

    private var shouldEnableBoundarySwipe: Bool {
      supportsBoundarySwipe
        && hasBoundarySwipeContext
        && !showingControls
        && !viewModel.isZoomed
        && viewModel.liveTextActivePageIndex == nil
    }

    private func boundaryAction(for translation: CGFloat) -> BoundaryNavigationAction? {
      if isAtFirstBoundary, let previousBook, readingDirection.isBackwardSwipe(translation) {
        return .openPrevious(previousBook.id)
      }
      if isAtEndBoundary, let nextBook, readingDirection.isForwardSwipe(translation) {
        return .openNext(nextBook.id)
      }
      return nil
    }

    private var boundarySwipeGesture: some Gesture {
      DragGesture(minimumDistance: 6, coordinateSpace: .local)
        .onChanged { value in
          guard shouldEnableBoundarySwipe else {
            resetBoundarySwipeState(animated: false)
            return
          }

          boundaryDragOffset = mode.isVertical ? value.translation.height : value.translation.width

          let currentAction = boundaryAction(for: boundaryDragOffset)
          onBoundaryPanUpdate?(currentAction != nil ? boundaryDragOffset : 0)
          if currentAction != nil
            && abs(boundaryDragOffset) >= boundarySwipeThreshold
            && !hasTriggeredBoundaryHaptic
          {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            hasTriggeredBoundaryHaptic = true
          } else if currentAction == nil {
            hasTriggeredBoundaryHaptic = false
          }
        }
        .onEnded { value in
          defer { resetBoundarySwipeState(animated: true) }
          guard shouldEnableBoundarySwipe else { return }

          let finalOffset = mode.isVertical ? value.translation.height : value.translation.width
          guard let action = boundaryAction(for: finalOffset) else { return }
          guard abs(finalOffset) >= boundarySwipeThreshold else { return }
          switch action {
          case .openPrevious(let previousBookId):
            onPreviousBook(previousBookId)
          case .openNext(let nextBookId):
            onNextBook(nextBookId)
          }
        }
    }

    private func resetBoundarySwipeState(animated: Bool) {
      onBoundaryPanUpdate?(0)
      if animated {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
          boundaryDragOffset = 0
          hasTriggeredBoundaryHaptic = false
        }
      } else {
        boundaryDragOffset = 0
        hasTriggeredBoundaryHaptic = false
      }
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
        case .end:
          EndPageView(
            viewModel: viewModel,
            nextBook: nextBook,
            readList: readList,
            onDismiss: onDismiss,
            onNextBook: onNextBook,
            readingDirection: readingDirection,
            showImage: true
          )
        case .dual(let first, let second):
          DualPageImageView(
            viewModel: viewModel,
            firstPageIndex: first,
            secondPageIndex: second,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls,
            onPlayAnimatedPage: onPlayAnimatedPage
          )
        case .page(let index):
          SinglePageImageView(
            viewModel: viewModel,
            pageIndex: index,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls,
            onPlayAnimatedPage: onPlayAnimatedPage
          )
        case .split(let index, let isFirstHalf):
          let isLeftHalf = viewModel.isLeftSplitHalf(
            isFirstHalf: isFirstHalf,
            readingDirection: readingDirection,
            splitWidePageMode: splitWidePageMode
          )
          SplitWidePageImageView(
            viewModel: viewModel,
            pageIndex: index,
            isLeftHalf: isLeftHalf,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls,
            onPlayAnimatedPage: onPlayAnimatedPage
          )
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
    guard !viewModel.pages.isEmpty else { return }

    let target = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .center)
      viewModel.updateCurrentPosition(viewItemIndex: target)
      hasSyncedInitialScroll = true
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
    guard !viewModel.pages.isEmpty else { return }

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

    // Explicitly update progress
    Task {
      await viewModel.updateProgress()
      await viewModel.preloadPages()
    }
  }

  private func handleTargetViewItemChange(_ newTarget: Int, proxy: ScrollViewProxy) {
    guard hasSyncedInitialScroll else { return }
    guard newTarget >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }
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

    // Explicitly update progress
    Task {
      await viewModel.updateProgress()
      await viewModel.preloadPages()
    }
  }

}
