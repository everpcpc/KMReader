//
//  ComicPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ComicPageView: View {
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void
  let screenSize: CGSize

  @State private var hasSyncedInitialScroll = false
  @State private var scrollPosition: Int?
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  var body: some View {
    ZStack {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          LazyHStack(spacing: 0) {
            // Single page mode
            ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
              SinglePageImageView(
                viewModel: viewModel,
                pageIndex: pageIndex,
                screenSize: screenSize
              )
              .frame(width: screenSize.width, height: screenSize.height)
              .contentShape(Rectangle())
              .simultaneousGesture(
                horizontalTapGesture(width: screenSize.width, proxy: proxy)
              )
              .id(pageIndex)
            }

            // End page at the end for LTR
            ZStack {
              readerBackground.color.ignoresSafeArea()
              EndPageView(
                nextBook: nextBook,
                onDismiss: onDismiss,
                onNextBook: onNextBook,
                isRTL: false
              )
            }
            .frame(width: screenSize.width, height: screenSize.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
              horizontalTapGesture(width: screenSize.width, proxy: proxy)
            )
            .id(viewModel.pages.count)
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
        .onChange(of: viewModel.targetPageIndex) { _, newTarget in
          guard let newTarget = newTarget else { return }
          guard hasSyncedInitialScroll else { return }
          guard newTarget >= 0 else { return }
          guard !viewModel.pages.isEmpty else { return }

          // Single page mode only
          let target = min(newTarget, viewModel.pages.count)

          // Update scroll position and currentPageIndex
          if scrollPosition != target {
            withAnimation {
              scrollPosition = target
              proxy.scrollTo(target, anchor: .leading)
            }
          }

          // Update currentPageIndex
          if viewModel.currentPageIndex != newTarget {
            viewModel.currentPageIndex = newTarget
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
          // Single page mode only
          let newIndex = min(viewModel.currentPageIndex - 1, viewModel.pages.count)
          viewModel.targetPageIndex = newIndex
        } else if normalizedX > 0.65 {
          guard !viewModel.pages.isEmpty else { return }

          // Next page (right tap)
          // Single page mode only
          let newIndex = min(viewModel.currentPageIndex + 1, viewModel.pages.count)
          viewModel.targetPageIndex = newIndex
        } else {
          toggleControls()
        }
      }
  }

  private func synchronizeInitialScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !hasSyncedInitialScroll else { return }
    guard viewModel.currentPageIndex >= 0 else { return }
    guard !viewModel.pages.isEmpty else { return }

    // Single page mode only
    let target = max(0, min(viewModel.currentPageIndex, viewModel.pages.count - 1))

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .leading)
      hasSyncedInitialScroll = true
    }
  }

  private func handleScrollPositionChange(_ target: Int?) {
    guard hasSyncedInitialScroll, let target else { return }

    // Single page mode only
    guard target >= 0, target <= viewModel.pages.count else { return }
    let newPageIndex = target

    // Update currentPageIndex when scroll position changes (user manually scrolled)
    if viewModel.currentPageIndex != newPageIndex {
      viewModel.currentPageIndex = newPageIndex
      viewModel.targetPageIndex = nil
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }
}
