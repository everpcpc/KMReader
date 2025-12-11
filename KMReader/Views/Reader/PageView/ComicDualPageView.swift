//
//  ComicDualPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ComicDualPageView: View {
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

  @Environment(\.readerBackgroundPreference) private var readerBackground

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?
  @State private var isZoomed = false

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        LazyHStack(spacing: 0) {
          ForEach(viewModel.pagePairs, id: \.self) { pagePair in
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
                    isRTL: false,
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
                    isRTL: false,
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
            #if os(iOS)
              .contentShape(Rectangle())
              .simultaneousGesture(
                horizontalTapGesture(width: screenSize.width, proxy: proxy)
              )
            #endif
            .id(pagePair.first)
            .readerPageScrollTransition()
          }
        }
        .scrollTargetLayout()
      }
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
      .onChange(of: viewModel.targetPageIndex) { _, newTargetIndex in
        guard let newTargetIndex = newTargetIndex else { return }
        guard hasSyncedInitialScroll else { return }
        guard !viewModel.pages.isEmpty else { return }

        let targetPair = viewModel.dualPageIndices[newTargetIndex]
        guard let targetPair = targetPair else { return }

        // Update scroll position and currentPageIndex
        if scrollPosition != targetPair.first {
          withAnimation(PlatformHelper.readerAnimation) {
            scrollPosition = targetPair.first
            proxy.scrollTo(targetPair.first, anchor: .leading)
          }
        }

        // Update currentPageIndex
        if viewModel.currentPageIndex != targetPair.first {
          viewModel.currentPageIndex = targetPair.first
          Task(priority: .userInitiated) {
            await viewModel.preloadPages()
          }
        }
      }
      .onChange(of: scrollPosition) { _, newTarget in
        handleScrollPositionChange(newTarget)
      }
    }
  }

  #if os(iOS)
    private func horizontalTapGesture(width: CGFloat, proxy: ScrollViewProxy) -> some Gesture {
      SpatialTapGesture()
        .onEnded { value in
          guard !isZoomed else { return }
          guard width > 0 else { return }
          let normalizedX = max(0, min(1, value.location.x / width))
          if normalizedX < 0.3 {
            guard !viewModel.pages.isEmpty else { return }
            guard viewModel.currentPageIndex > 0 else { return }

            // Previous page (left tap)
            let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
            guard let currentPair = currentPair else { return }
            viewModel.targetPageIndex = max(0, currentPair.first - 1)
          } else if normalizedX > 0.7 {
            guard !viewModel.pages.isEmpty else { return }

            // Next page (right tap)
            let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
            guard let currentPair = currentPair else { return }
            if let second = currentPair.second {
              viewModel.targetPageIndex = min(viewModel.pages.count, second + 1)
            } else {
              viewModel.targetPageIndex = min(viewModel.pages.count, currentPair.first + 1)
            }
          } else {
            toggleControls()
          }
        }
    }
  #endif

  private func synchronizeInitialScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !hasSyncedInitialScroll else { return }
    guard viewModel.currentPageIndex >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    let dualPageIndex = viewModel.dualPageIndices[viewModel.currentPageIndex]
    guard let dualPageIndex = dualPageIndex else { return }

    DispatchQueue.main.async {
      scrollPosition = dualPageIndex.first
      proxy.scrollTo(dualPageIndex.first, anchor: .leading)
      hasSyncedInitialScroll = true
    }
  }

  private func handleScrollPositionChange(_ target: Int?) {
    guard hasSyncedInitialScroll, let target else { return }
    guard target >= 0 else { return }

    let targetPair = viewModel.dualPageIndices[target]
    guard let targetPair = targetPair else { return }
    guard targetPair.first < viewModel.pages.count else { return }

    // Update currentPageIndex when scroll position changes (user manually scrolled)
    if viewModel.currentPageIndex != targetPair.first {
      viewModel.currentPageIndex = targetPair.first
      viewModel.targetPageIndex = nil
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }
}
