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
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void
  let screenSize: CGSize

  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?

  var body: some View {
    ZStack {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          LazyHStack(spacing: 0) {
            ForEach(viewModel.pagePairs, id: \.self) { pagePair in
              Group {
                if pagePair.first == viewModel.pages.count {
                  ZStack {
                    readerBackground.color.ignoresSafeArea()
                    EndPageView(
                      nextBook: nextBook,
                      onDismiss: onDismiss,
                      onNextBook: onNextBook,
                      isRTL: false
                    )
                  }
                } else {
                  if let second = pagePair.second {
                    DualPageImageView(
                      viewModel: viewModel,
                      firstPageIndex: pagePair.first,
                      secondPageIndex: second,
                      screenSize: screenSize,
                      isRTL: false
                    )
                  } else {
                    SinglePageImageView(
                      viewModel: viewModel,
                      pageIndex: pagePair.first,
                      screenSize: screenSize
                    )
                  }
                }
              }
              .frame(width: screenSize.width, height: screenSize.height)
              .contentShape(Rectangle())
              .simultaneousGesture(
                horizontalTapGesture(width: screenSize.width, proxy: proxy)
              )
              .id(pagePair.first)
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
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
            withAnimation {
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
  }

  private func horizontalTapGesture(width: CGFloat, proxy: ScrollViewProxy) -> some Gesture {
    SpatialTapGesture()
      .onEnded { value in
        guard width > 0 else { return }
        let normalizedX = max(0, min(1, value.location.x / width))
        if normalizedX < 0.25 {
          guard !viewModel.pages.isEmpty else { return }
          guard viewModel.currentPageIndex > 0 else { return }

          // Previous page (left tap)
          let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
          guard let currentPair = currentPair else { return }
          viewModel.targetPageIndex = max(0, currentPair.first - 1)
        } else if normalizedX > 0.65 {
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
