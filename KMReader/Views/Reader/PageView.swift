//
//  PageView.swift
//  Komga
//

import SwiftUI

enum PageViewMode {
  case comicSingle  // LTR horizontal single-page
  case mangaSingle  // RTL horizontal single-page
  case comicDual  // LTR horizontal dual-page
  case mangaDual  // RTL horizontal dual-page
  case vertical  // Vertical scrolling single-page

  init(direction: ReadingDirection, useDualPage: Bool) {
    switch direction {
    case .ltr:
      self = useDualPage ? .comicDual : .comicSingle
    case .rtl:
      self = useDualPage ? .mangaDual : .mangaSingle
    case .vertical, .webtoon:
      self = .vertical
    }
  }

  var isRTL: Bool {
    self == .mangaSingle || self == .mangaDual
  }

  var isDualPage: Bool {
    self == .comicDual || self == .mangaDual
  }

  var isVertical: Bool {
    self == .vertical
  }

  var scrollAnchor: UnitPoint {
    switch self {
    case .comicSingle, .comicDual:
      return .leading
    case .mangaSingle, .mangaDual:
      return .trailing
    case .vertical:
      return .top
    }
  }
}

struct PageView: View {
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
  let screenSize: CGSize
  let onEndPageFocusChange: ((Bool) -> Void)?

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?
  @State private var isZoomed = false
  @Environment(\.readerBackgroundPreference) private var readerBackground
  @AppStorage("pageTransitionStyle") private var pageTransitionStyle: PageTransitionStyle = .simple
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false

  var body: some View {
    ScrollViewReader { proxy in
      scrollViewContent(proxy: proxy)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
        .scrollDisabled(isZoomed)
        #if os(tvOS)
          .focusable(false)
        #endif
        .onAppear {
          synchronizeInitialScrollIfNeeded(proxy: proxy)
        }
        .onChange(of: viewModel.pages.count) {
          hasSyncedInitialScroll = false
          synchronizeInitialScrollIfNeeded(proxy: proxy)
        }
        .onChange(of: viewModel.targetPageIndex) { _, newTarget in
          handleTargetPageChange(newTarget, proxy: proxy)
        }
        .onChange(of: scrollPosition) { _, newTarget in
          handleScrollPositionChange(newTarget)
        }
    }
  }

  @ViewBuilder
  private func scrollViewContent(proxy: ScrollViewProxy) -> some View {
    if mode.isVertical {
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          verticalPageContent(proxy: proxy)
        }
        .scrollTargetLayout()
      }
    } else {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 0) {
          horizontalPageContent(proxy: proxy)
        }
        .scrollTargetLayout()
      }
    }
  }

  // MARK: - Vertical Content

  @ViewBuilder
  private func verticalPageContent(proxy: ScrollViewProxy) -> some View {
    ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
      singlePageView(pageIndex: pageIndex)
        .frame(width: screenSize.width, height: screenSize.height)
        .pageTapGesture(
          size: screenSize,
          readingDirection: readingDirection,
          onNextPage: goToNextPage,
          onPreviousPage: goToPreviousPage,
          onToggleControls: toggleControls
        )
        .id(pageIndex)
        .readerPageScrollTransition(style: pageTransitionStyle, axis: .vertical)
    }

    // End page
    ZStack {
      readerBackground.color.readerIgnoresSafeArea()
      EndPageView(
        viewModel: viewModel,
        nextBook: nextBook,
        readList: readList,
        onDismiss: onDismiss,
        onNextBook: onNextBook,
        isRTL: false,
        onFocusChange: onEndPageFocusChange
      )
    }
    // Add 100 to height to prevent bounce behavior
    .frame(width: screenSize.width, height: screenSize.height + 100)
    .pageTapGesture(
      size: screenSize,
      readingDirection: readingDirection,
      onNextPage: goToNextPage,
      onPreviousPage: goToPreviousPage,
      onToggleControls: toggleControls
    )
    .id(viewModel.pages.count)
  }

  // MARK: - Horizontal Content

  @ViewBuilder
  private func horizontalPageContent(proxy: ScrollViewProxy) -> some View {
    if mode.isDualPage {
      dualPageContent(proxy: proxy)
    } else {
      singlePageHorizontalContent(proxy: proxy)
    }
  }

  @ViewBuilder
  private func singlePageHorizontalContent(proxy: ScrollViewProxy) -> some View {
    // For RTL (manga), end page comes first, then pages in reverse
    // For LTR (comic), pages come first, then end page
    if mode.isRTL {
      // End page at beginning for RTL
      endPageView(proxy: proxy)
        .id(viewModel.pages.count)
        .readerPageScrollTransition(style: pageTransitionStyle)

      // Pages in reverse order
      ForEach((0..<viewModel.pages.count).reversed(), id: \.self) { pageIndex in
        singlePageView(pageIndex: pageIndex)
          .frame(width: screenSize.width, height: screenSize.height)
          .pageTapGesture(
            size: screenSize,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls
          )
          .id(pageIndex)
          .readerPageScrollTransition(style: pageTransitionStyle)
      }
    } else {
      // Pages in normal order
      ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
        singlePageView(pageIndex: pageIndex)
          .frame(width: screenSize.width, height: screenSize.height)
          .pageTapGesture(
            size: screenSize,
            readingDirection: readingDirection,
            onNextPage: goToNextPage,
            onPreviousPage: goToPreviousPage,
            onToggleControls: toggleControls
          )
          .id(pageIndex)
          .readerPageScrollTransition(style: pageTransitionStyle)
      }

      // End page at end for LTR
      endPageView(proxy: proxy)
        .id(viewModel.pages.count)
        .readerPageScrollTransition(style: pageTransitionStyle)
    }
  }

  @ViewBuilder
  private func dualPageContent(proxy: ScrollViewProxy) -> some View {
    let pairs = mode.isRTL ? viewModel.pagePairs.reversed() : viewModel.pagePairs

    ForEach(Array(pairs), id: \.self) { pagePair in
      Group {
        if pagePair.first == viewModel.pages.count {
          // End page
          ZStack {
            readerBackground.color.readerIgnoresSafeArea()
            EndPageView(
              viewModel: viewModel,
              nextBook: nextBook,
              readList: readList,
              onDismiss: onDismiss,
              onNextBook: onNextBook,
              isRTL: mode.isRTL,
              onFocusChange: onEndPageFocusChange
            )
          }
        } else {
          // Regular pages
          if let second = pagePair.second {
            DualPageImageView(
              viewModel: viewModel,
              firstPageIndex: pagePair.first,
              secondPageIndex: second,
              screenSize: screenSize,
              isRTL: mode.isRTL,
              isZoomed: $isZoomed
            )
          } else {
            SinglePageImageView(
              viewModel: viewModel,
              pageIndex: pagePair.first,
              screenSize: screenSize,
              isZoomed: $isZoomed
            )
          }
        }
      }
      .frame(width: screenSize.width, height: screenSize.height)
      .pageTapGesture(
        size: screenSize,
        readingDirection: readingDirection,
        onNextPage: goToNextPage,
        onPreviousPage: goToPreviousPage,
        onToggleControls: toggleControls
      )
      .id(pagePair.first)
      .readerPageScrollTransition(style: pageTransitionStyle)
    }
  }

  // MARK: - Helper Views

  @ViewBuilder
  private func singlePageView(pageIndex: Int) -> some View {
    SinglePageImageView(
      viewModel: viewModel,
      pageIndex: pageIndex,
      screenSize: screenSize,
      isZoomed: $isZoomed
    )
  }

  @ViewBuilder
  private func endPageView(proxy: ScrollViewProxy) -> some View {
    ZStack {
      readerBackground.color.readerIgnoresSafeArea()
      EndPageView(
        viewModel: viewModel,
        nextBook: nextBook,
        readList: readList,
        onDismiss: onDismiss,
        onNextBook: onNextBook,
        isRTL: mode.isRTL,
        onFocusChange: onEndPageFocusChange
      )
    }
    .frame(width: screenSize.width, height: screenSize.height)
    .pageTapGesture(
      size: screenSize,
      readingDirection: readingDirection,
      onNextPage: goToNextPage,
      onPreviousPage: goToPreviousPage,
      onToggleControls: toggleControls
    )
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
      proxy.scrollTo(target, anchor: mode.scrollAnchor)
      hasSyncedInitialScroll = true
    }
  }

  private func handleTargetPageChange(_ newTarget: Int?, proxy: ScrollViewProxy) {
    guard let newTarget = newTarget else { return }
    guard hasSyncedInitialScroll else { return }
    guard newTarget >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    let targetScrollPosition: Int
    let pageIndexToUpdate: Int

    if mode.isDualPage {
      guard let targetPair = viewModel.dualPageIndices[newTarget] else { return }
      targetScrollPosition = targetPair.first
      pageIndexToUpdate = targetPair.first
    } else {
      targetScrollPosition = min(newTarget, viewModel.pages.count)
      pageIndexToUpdate = newTarget
    }

    if scrollPosition != targetScrollPosition {
      withAnimation(pageTransitionStyle.scrollAnimation) {
        scrollPosition = targetScrollPosition
        proxy.scrollTo(targetScrollPosition, anchor: mode.scrollAnchor)
      }
    }

    if viewModel.currentPageIndex != pageIndexToUpdate {
      viewModel.currentPageIndex = pageIndexToUpdate
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }

  private func handleScrollPositionChange(_ target: Int?) {
    guard hasSyncedInitialScroll, let target else { return }

    let newPageIndex: Int

    if mode.isDualPage {
      guard target >= 0 else { return }
      guard let targetPair = viewModel.dualPageIndices[target] else { return }
      guard targetPair.first <= viewModel.pages.count else { return }
      newPageIndex = targetPair.first
    } else {
      guard target >= 0, target <= viewModel.pages.count else { return }
      newPageIndex = target
    }

    if viewModel.currentPageIndex != newPageIndex {
      viewModel.currentPageIndex = newPageIndex
      viewModel.targetPageIndex = nil
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }
}
