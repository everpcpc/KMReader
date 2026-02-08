//
//  ScrollPageView.swift
//  Komga
//

import SwiftUI

struct ScrollPageView: View {
  let mode: PageViewMode
  let readingDirection: ReadingDirection
  let splitWidePageMode: SplitWidePageMode
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let readList: ReadList?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void

  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?

  init(
    mode: PageViewMode,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode,
    viewModel: ReaderViewModel,
    nextBook: Book?,
    readList: ReadList?,
    onDismiss: @escaping () -> Void,
    onNextBook: @escaping (String) -> Void,
    goToNextPage: @escaping () -> Void,
    goToPreviousPage: @escaping () -> Void,
    toggleControls: @escaping () -> Void
  ) {
    self.mode = mode
    self.readingDirection = readingDirection
    self.splitWidePageMode = splitWidePageMode
    self.viewModel = viewModel
    self.nextBook = nextBook
    self.readList = readList
    self.onDismiss = onDismiss
    self.onNextBook = onNextBook
    self.goToNextPage = goToNextPage
    self.goToPreviousPage = goToPreviousPage
    self.toggleControls = toggleControls
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
        scrollViewContent(
          geometry: geometry,
          isScrollDisabled: viewModel.isZoomed || viewModel.liveTextActivePageIndex != nil
        )
        .frame(width: geometry.size.width, height: geometry.size.height)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onAppear {
          synchronizeInitialScrollIfNeeded(proxy: proxy)
        }
        .onChange(of: viewModel.targetPageIndex) { _, newTarget in
          if let newTarget = newTarget {
            handleTargetPageChange(newTarget, proxy: proxy)
            Task { @MainActor in
              viewModel.targetPageIndex = nil
            }
          }
        }
        .onChange(of: viewModel.targetViewItemIndex) { _, newTarget in
          if let newTarget = newTarget {
            handleTargetViewItemChange(newTarget, proxy: proxy)
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
        }
        .onChange(of: scrollPosition) { _, newPosition in
          if let newPosition, newPosition < viewModel.viewItems.count {
            viewModel.updateCurrentPosition(viewItemIndex: newPosition)

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
            onPreviousPage: goToPreviousPage,
            onFocusChange: nil,
            isActive: offset == viewModel.currentViewItemIndex,
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
            onToggleControls: toggleControls
          )
        case .page(let index):
          SinglePageImageView(
            viewModel: viewModel,
            pageIndex: index,
            screenSize: geometry.size,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls
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
            onToggleControls: toggleControls
          )
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .id(offset)
      .readerPageScrollTransition()
    }
  }

  private func synchronizeInitialScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !hasSyncedInitialScroll else { return }
    guard viewModel.currentPageIndex >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    let target = viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)

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

    let targetScrollPosition = viewModel.viewItemIndex(forPageIndex: newTarget)

    if scrollPosition != targetScrollPosition {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: .center)
      }
    }

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

    if scrollPosition != newTarget {
      let animation: Animation? =
        tapPageTransitionDuration > 0 ? .easeInOut(duration: tapPageTransitionDuration) : nil
      withAnimation(animation) {
        scrollPosition = newTarget
        proxy.scrollTo(newTarget, anchor: .center)
      }
    }

    Task {
      await viewModel.updateProgress()
      await viewModel.preloadPages()
    }
  }
}
