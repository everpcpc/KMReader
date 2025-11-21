//
//  MangaPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct MangaPageView: View {
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
            // End page at the beginning for RTL
            ZStack {
              readerBackground.color.ignoresSafeArea()
              EndPageView(
                nextBook: nextBook,
                onDismiss: onDismiss,
                onNextBook: onNextBook,
                isRTL: true,
              )
            }
            .frame(width: screenSize.width, height: screenSize.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
              horizontalTapGesture(width: screenSize.width, proxy: proxy)
            )
            .id(viewModel.pages.count)

            // Pages in reverse order for RTL (last to first)
            ForEach((0..<viewModel.pages.count).reversed(), id: \.self) { pageIndex in
              PageImageView(viewModel: viewModel, pageIndex: pageIndex)
                .frame(width: screenSize.width, height: screenSize.height)
                .contentShape(Rectangle())
                .simultaneousGesture(
                  horizontalTapGesture(width: screenSize.width, proxy: proxy)
                )
                .id(pageIndex)
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
        .onChange(of: viewModel.currentPageIndex) { _, newIndex in
          guard hasSyncedInitialScroll else { return }
          guard newIndex >= 0 else { return }
          guard !viewModel.pages.isEmpty else { return }

          let target = min(newIndex, viewModel.pages.count)
          if scrollPosition != target {
            withAnimation {
              scrollPosition = target
              proxy.scrollTo(target, anchor: .trailing)
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
        if normalizedX < 0.35 {
          guard !viewModel.pages.isEmpty else { return }
          // Next page (left tap for RTL means go forward)
          viewModel.currentPageIndex = min(viewModel.currentPageIndex + 1, viewModel.pages.count)
          withAnimation {
            scrollPosition = viewModel.currentPageIndex
            proxy.scrollTo(viewModel.currentPageIndex, anchor: .trailing)
          }
        } else if normalizedX > 0.75 {
          guard !viewModel.pages.isEmpty else { return }
          // Previous page (right tap for RTL means go back)
          guard viewModel.currentPageIndex > 0 else { return }
          let current = min(viewModel.currentPageIndex, viewModel.pages.count)
          viewModel.currentPageIndex = current - 1
          withAnimation {
            scrollPosition = viewModel.currentPageIndex
            proxy.scrollTo(viewModel.currentPageIndex, anchor: .trailing)
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

    let target = max(0, min(viewModel.currentPageIndex, viewModel.pages.count - 1))

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .trailing)
      hasSyncedInitialScroll = true
    }
  }

  private func handleScrollPositionChange(_ target: Int?) {
    guard hasSyncedInitialScroll, let target else { return }
    guard target >= 0, target <= viewModel.pages.count else { return }

    if viewModel.currentPageIndex != target {
      viewModel.currentPageIndex = target
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }
}
