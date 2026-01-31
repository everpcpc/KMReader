//
//  ScrollPageView.swift
//  Komga
//

import SwiftUI

struct ScrollPageView: View {
  let mode: PageViewMode
  let readingDirection: ReadingDirection
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let readList: ReadList?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void
  let onEndPageFocusChange: ((Bool) -> Void)?
  let onScrollActivityChange: ((Bool) -> Void)?

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?

  init(
    mode: PageViewMode,
    readingDirection: ReadingDirection,
    viewModel: ReaderViewModel,
    nextBook: Book?,
    readList: ReadList?,
    onDismiss: @escaping () -> Void,
    onNextBook: @escaping (String) -> Void,
    goToNextPage: @escaping () -> Void,
    goToPreviousPage: @escaping () -> Void,
    toggleControls: @escaping () -> Void,
    onEndPageFocusChange: ((Bool) -> Void)?,
    onScrollActivityChange: ((Bool) -> Void)? = nil
  ) {
    self.mode = mode
    self.readingDirection = readingDirection
    self.viewModel = viewModel
    self.nextBook = nextBook
    self.readList = readList
    self.onDismiss = onDismiss
    self.onNextBook = onNextBook
    self.goToNextPage = goToNextPage
    self.goToPreviousPage = goToPreviousPage
    self.toggleControls = toggleControls
    self.onEndPageFocusChange = onEndPageFocusChange
    self.onScrollActivityChange = onScrollActivityChange
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
        scrollViewContent(
          proxy: proxy, geometry: geometry,
          isScrollDisabled: viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil
        )
        .frame(width: geometry.size.width, height: geometry.size.height)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        #if os(tvOS)
          .focusable(false)
        #endif
        .onAppear {
          synchronizeInitialScrollIfNeeded(proxy: proxy)
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
        .onChange(of: scrollPosition) { _, newPosition in
          if let newPosition {
            // For split pages mode, convert view item index back to page index
            let hasSplitPages = viewModel.pagePairs.contains { $0.isSplitPage }
            if hasSplitPages && !mode.isDualPage {
              if newPosition < viewModel.pagePairs.count {
                let pagePair = viewModel.pagePairs[newPosition]
                viewModel.currentPageIndex = pagePair.first
                viewModel.currentViewItemIndex = newPosition  // Track position in pagePairs array
              }
            } else {
              viewModel.currentPageIndex = newPosition
              viewModel.currentViewItemIndex = newPosition
            }

            // Clear targetPageIndex if the user manually scrolled
            if viewModel.targetPageIndex != nil {
              viewModel.targetPageIndex = nil
            }
            if viewModel.targetViewItemIndex != nil {
              viewModel.targetViewItemIndex = nil
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func scrollViewContent(proxy: ScrollViewProxy, geometry: GeometryProxy, isScrollDisabled: Bool) -> some View {
    ScrollView(mode.isVertical ? .vertical : .horizontal) {
      if mode.isVertical {
        LazyVStack(spacing: 0) {
          // Check if split wide pages is enabled for vertical mode too
          let hasSplitPages = viewModel.pagePairs.contains { $0.isSplitPage }
          if hasSplitPages {
            splitPageContent(proxy: proxy, geometry: geometry)
          } else {
            singlePageContent(proxy: proxy, geometry: geometry)
          }
        }
        .scrollTargetLayout()
      } else {
        LazyHStack(spacing: 0) {
          if mode.isDualPage {
            dualPageContent(proxy: proxy, geometry: geometry)
          } else {
            singlePageContent(proxy: proxy, geometry: geometry)
          }
        }
        .scrollTargetLayout()
      }
    }
    .scrollIndicators(.never)
    .scrollDisabled(isScrollDisabled)
    .environment(\.layoutDirection, mode.isRTL ? .rightToLeft : .leftToRight)
  }

  private func singlePageContent(proxy: ScrollViewProxy, geometry: GeometryProxy) -> some View {
    // Check if split wide pages is enabled by examining pagePairs
    let hasSplitPages = viewModel.pagePairs.contains { $0.isSplitPage }

    if hasSplitPages {
      // Use pagePairs for rendering when split pages are enabled
      return AnyView(splitPageContent(proxy: proxy, geometry: geometry))
    } else {
      // Use traditional page index iteration
      return AnyView(
        ForEach(0...viewModel.pages.count, id: \.self) { index in
          Group {
            if index == viewModel.pages.count {
              EndPageView(
                viewModel: viewModel,
                nextBook: nextBook,
                readList: readList,
                onDismiss: onDismiss,
                onNextBook: onNextBook,
                readingDirection: readingDirection,
                onPreviousPage: goToPreviousPage,
                onFocusChange: onEndPageFocusChange,
                showImage: true,
              )
            } else {
              SinglePageImageView(
                viewModel: viewModel,
                pageIndex: index,
                screenSize: geometry.size,
                readingDirection: readingDirection,
                onNextPage: goToNextPage,
                onPreviousPage: goToPreviousPage,
                onToggleControls: toggleControls
              )
            }
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
          .id(index)
          .readerPageScrollTransition()
        }
      )
    }
  }

  private func splitPageContent(proxy: ScrollViewProxy, geometry: GeometryProxy) -> some View {
    var pairIndex = 0
    return ForEach(Array(viewModel.pagePairs.enumerated()), id: \.offset) { offset, pagePair in
      Group {
        if pagePair.first == viewModel.pages.count {
          EndPageView(
            viewModel: viewModel,
            nextBook: nextBook,
            readList: readList,
            onDismiss: onDismiss,
            onNextBook: onNextBook,
            readingDirection: readingDirection,
            onPreviousPage: goToPreviousPage,
            onFocusChange: onEndPageFocusChange,
            showImage: true
          )
        } else if pagePair.isSplitPage {
          // Determine if this is the left or right half based on reading direction and swap setting
          let isLeftHalf: Bool = {
            // Find the first occurrence of this split page
            guard let firstIndex = viewModel.pagePairs.firstIndex(where: { $0.first == pagePair.first && $0.isSplitPage }) else {
              return true
            }

            let isFirstHalf = offset == firstIndex

            // Determine the base order based on reading direction
            var shouldShowLeftFirst: Bool
            if readingDirection == .rtl {
              shouldShowLeftFirst = false  // RTL: right half first by default
            } else {
              shouldShowLeftFirst = true   // LTR: left half first by default
            }

            // Apply swap if enabled
            if pagePair.swapOrder {
              shouldShowLeftFirst = !shouldShowLeftFirst
            }

            // Return whether this position should show left half
            return shouldShowLeftFirst ? isFirstHalf : !isFirstHalf
          }()

          SplitWidePageImageView(
            viewModel: viewModel,
            pageIndex: pagePair.first,
            isLeftHalf: isLeftHalf,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls
          )
        } else {
          SinglePageImageView(
            viewModel: viewModel,
            pageIndex: pagePair.first,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls
          )
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .id(offset)
      .readerPageScrollTransition()
    }
  }

  private func dualPageContent(proxy: ScrollViewProxy, geometry: GeometryProxy) -> some View {
    ForEach(Array(viewModel.pagePairs), id: \.self) { pagePair in
      Group {
        if pagePair.first == viewModel.pages.count {
          EndPageView(
            viewModel: viewModel,
            nextBook: nextBook,
            readList: readList,
            onDismiss: onDismiss,
            onNextBook: onNextBook,
            readingDirection: readingDirection,
            onPreviousPage: goToPreviousPage,
            onFocusChange: onEndPageFocusChange,
            showImage: readingDirection != .webtoon
          )
        } else {
          if let second = pagePair.second {
            DualPageImageView(
              viewModel: viewModel,
              firstPageIndex: pagePair.first,
              secondPageIndex: second,
              screenSize: geometry.size,
              readingDirection: readingDirection,
              onNextPage: goToNextPage,
              onPreviousPage: goToPreviousPage,
              onToggleControls: toggleControls
            )
          } else {
            SinglePageImageView(
              viewModel: viewModel,
              pageIndex: pagePair.first,
              screenSize: geometry.size,
              readingDirection: readingDirection,
              onNextPage: goToNextPage,
              onPreviousPage: goToPreviousPage,
              onToggleControls: toggleControls
            )
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .id(pagePair.first)
      .readerPageScrollTransition()
    }
  }

  // MARK: - Scroll Synchronization

  private func synchronizeInitialScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !hasSyncedInitialScroll else { return }
    guard viewModel.currentPageIndex >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    let target: Int
    if mode.isDualPage {
      guard let dualPageIndex = viewModel.dualPageIndices[viewModel.currentPageIndex] else {
        return
      }
      target = dualPageIndex.first
    } else {
      // Check if split pages are enabled
      let hasSplitPages = viewModel.pagePairs.contains { $0.isSplitPage }
      if hasSplitPages {
        // Find the view item index for this page
        target = findViewItemIndexForPage(viewModel.currentPageIndex)
      } else {
        target = max(0, min(viewModel.currentPageIndex, viewModel.pages.count - 1))
      }
    }

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .center)
      hasSyncedInitialScroll = true
    }
  }

  private func handleTargetPageChange(_ newTarget: Int?, proxy: ScrollViewProxy) {
    guard let newTarget = newTarget else { return }
    guard hasSyncedInitialScroll else { return }
    guard newTarget >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    let targetScrollPosition: Int

    if mode.isDualPage {
      guard let targetPair = viewModel.dualPageIndices[newTarget] else { return }
      targetScrollPosition = targetPair.first
    } else {
      // Check if split pages are enabled
      let hasSplitPages = viewModel.pagePairs.contains { $0.isSplitPage }
      if hasSplitPages {
        // Find the view item index for this page
        targetScrollPosition = findViewItemIndexForPage(newTarget)
      } else {
        targetScrollPosition = min(newTarget, viewModel.pages.count)
      }
    }

    if scrollPosition != targetScrollPosition {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: .center)
      }
    }

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
    guard newTarget < viewModel.pagePairs.count else { return }

    let targetScrollPosition = newTarget

    if scrollPosition != targetScrollPosition {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: .center)
      }
    }

    // Explicitly update progress
    Task {
      await viewModel.updateProgress()
      await viewModel.preloadPages()
    }
  }

  // Helper function to find the view item index for a given page index in split mode
  private func findViewItemIndexForPage(_ pageIndex: Int) -> Int {
    var viewItemIndex = 0
    for (index, pagePair) in viewModel.pagePairs.enumerated() {
      if pagePair.first == pageIndex {
        return index
      }
      viewItemIndex = index
    }
    return min(pageIndex, viewModel.pagePairs.count - 1)
  }
}
