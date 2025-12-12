//
//  VerticalPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct VerticalPageView: View {
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

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
            SinglePageImageView(
              viewModel: viewModel,
              pageIndex: pageIndex,
              screenSize: screenSize,
              isZoomed: $isZoomed
            )
            .frame(width: screenSize.width, height: screenSize.height)
            #if os(iOS) || os(macOS)
              .contentShape(Rectangle())
              .simultaneousGesture(
                verticalTapGesture(height: screenSize.height, proxy: proxy)
              )
            #endif
            .id(pageIndex)
            .readerPageScrollTransition(style: pageTransitionStyle)
          }

          // End page after last page
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
          // IMPORTANT: Add 100 to the height to prevent the bounce behavior
          .frame(width: screenSize.width, height: screenSize.height + 100)
          #if os(iOS) || os(macOS)
            .contentShape(Rectangle())
            .simultaneousGesture(
              verticalTapGesture(height: screenSize.height, proxy: proxy)
            )
          #endif
          .id(viewModel.pages.count)
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
      .onChange(of: viewModel.targetPageIndex) { _, newTarget in
        guard let newTarget = newTarget else { return }
        guard hasSyncedInitialScroll else { return }
        guard newTarget >= 0 else { return }
        guard !viewModel.pages.isEmpty else { return }

        let target = min(newTarget, viewModel.pages.count)

        // Update scroll position and currentPageIndex
        if scrollPosition != target {
          withAnimation(pageTransitionStyle.scrollAnimation) {
            scrollPosition = target
            proxy.scrollTo(target, anchor: .top)
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

  #if os(iOS) || os(macOS)
    private func verticalTapGesture(height: CGFloat, proxy: ScrollViewProxy) -> some Gesture {
      SpatialTapGesture()
        .onEnded { value in
          guard !isZoomed else { return }
          guard height > 0 else { return }
          let normalizedY = max(0, min(1, value.location.y / height))
          if normalizedY < 0.3 {
            guard !viewModel.pages.isEmpty else { return }
            guard viewModel.currentPageIndex > 0 else { return }
            // Previous page (top tap)
            let current = min(viewModel.currentPageIndex, viewModel.pages.count)
            viewModel.targetPageIndex = current - 1
          } else if normalizedY > 0.7 {
            guard !viewModel.pages.isEmpty else { return }
            // Next page (bottom tap)
            viewModel.targetPageIndex = min(
              viewModel.currentPageIndex + 1, viewModel.pages.count)
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

    let target = max(0, min(viewModel.currentPageIndex, viewModel.pages.count - 1))

    DispatchQueue.main.async {
      scrollPosition = target
      proxy.scrollTo(target, anchor: .top)
      hasSyncedInitialScroll = true
    }
  }

  private func handleScrollPositionChange(_ target: Int?) {
    guard hasSyncedInitialScroll, let target else { return }
    guard target >= 0, target <= viewModel.pages.count else { return }

    // Update currentPageIndex when scroll position changes (user manually scrolled)
    if viewModel.currentPageIndex != target {
      viewModel.currentPageIndex = target
      viewModel.targetPageIndex = nil
      Task(priority: .userInitiated) {
        await viewModel.preloadPages()
      }
    }
  }
}
