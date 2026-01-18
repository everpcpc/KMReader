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
        scrollViewContent(proxy: proxy, geometry: geometry)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .scrollTargetBehavior(.paging)
          .scrollIndicators(.hidden)
          .scrollPosition(id: $scrollPosition)
          .scrollDisabled(viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil)
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
          .onChange(of: scrollPosition) { _, newPosition in
            if let newPosition {
              viewModel.currentPageIndex = newPosition
              // Clear targetPageIndex if the user manually scrolled
              if viewModel.targetPageIndex != nil {
                viewModel.targetPageIndex = nil
              }
            }
          }
      }
    }
  }

  @ViewBuilder
  private func scrollViewContent(proxy: ScrollViewProxy, geometry: GeometryProxy) -> some View {
    ScrollView(mode.isVertical ? .vertical : .horizontal) {
      if mode.isVertical {
        LazyVStack(spacing: 0) {
          singlePageContent(proxy: proxy, geometry: geometry)
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
    .environment(\.layoutDirection, mode.isRTL ? .rightToLeft : .leftToRight)
  }

  private func singlePageContent(proxy: ScrollViewProxy, geometry: GeometryProxy) -> some View {
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
      target = max(0, min(viewModel.currentPageIndex, viewModel.pages.count - 1))
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
      targetScrollPosition = min(newTarget, viewModel.pages.count)
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
}
