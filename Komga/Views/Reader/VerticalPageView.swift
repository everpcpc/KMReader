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
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let goToNextPage: () -> Void
  let goToPreviousPage: () -> Void
  let toggleControls: () -> Void

  @State private var hasSyncedInitialScroll = false
  @State private var showTapZoneOverlay = false
  @State private var scrollPosition: Int?
  @AppStorage("showTapZone") private var showTapZone: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  var body: some View {
    GeometryReader { screenGeometry in
      let screenKey = "\(Int(screenGeometry.size.width))x\(Int(screenGeometry.size.height))"

      ZStack {
        ScrollViewReader { proxy in
          ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
              ForEach(0..<viewModel.pages.count, id: \.self) { pageIndex in
                PageImageView(viewModel: viewModel, pageIndex: pageIndex)
                  .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                  .contentShape(Rectangle())
                  .simultaneousGesture(
                    verticalTapGesture(height: screenGeometry.size.height, proxy: proxy)
                  )
                  .id(pageIndex)
              }

              // End page after last page
              ZStack {
                readerBackground.color.ignoresSafeArea()
                EndPageView(
                  nextBook: nextBook,
                  onDismiss: onDismiss,
                  onNextBook: onNextBook,
                  isRTL: false
                )
              }
              // IMPORTANT: Add 100 to the height to prevent the bounce behavior
              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height + 100)
              .contentShape(Rectangle())
              .simultaneousGesture(
                verticalTapGesture(height: screenGeometry.size.height, proxy: proxy)
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
          .onChange(of: viewModel.currentPageIndex) { _, newIndex in
            guard hasSyncedInitialScroll else { return }
            guard newIndex >= 0 else { return }
            guard !viewModel.pages.isEmpty else { return }

            let target = min(newIndex, viewModel.pages.count)
            if scrollPosition != target {
              withAnimation {
                scrollPosition = target
                proxy.scrollTo(target, anchor: .top)
              }
            }
          }
          .id(screenKey)
          .onChange(of: screenKey) {
            // Reset scroll sync flag when screen size changes
            hasSyncedInitialScroll = false
          }
          .onChange(of: scrollPosition) { _, newTarget in
            handleScrollPositionChange(newTarget)
          }
        }

        // Tap zone overlay
        if showTapZoneOverlay {
          VerticalTapZoneOverlay()
        }
      }
      .onAppear {
        // Show tap zone overlay when view appears with pages loaded
        if showTapZone && !viewModel.pages.isEmpty && !showTapZoneOverlay {
          showTapZoneOverlay = true
        }
      }
      .onChange(of: viewModel.pages.count) { oldCount, newCount in
        // Show tap zone overlay when pages are first loaded
        if oldCount == 0 && newCount > 0 {
          triggerTapZoneDisplay()
        }
      }
      .onChange(of: screenKey) {
        // Show tap zone overlay when screen orientation changes
        triggerTapZoneDisplay()
      }
    }
  }

  private func triggerTapZoneDisplay() {
    guard showTapZone && !viewModel.pages.isEmpty else { return }
    showTapZoneOverlay = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      showTapZoneOverlay = true
    }
  }

  private func verticalTapGesture(height: CGFloat, proxy: ScrollViewProxy) -> some Gesture {
    SpatialTapGesture()
      .onEnded { value in
        guard height > 0 else { return }
        let normalizedY = max(0, min(1, value.location.y / height))
        if normalizedY < 0.25 {
          guard !viewModel.pages.isEmpty else { return }
          guard viewModel.currentPageIndex > 0 else { return }
          // Previous page (top tap)
          let current = min(viewModel.currentPageIndex, viewModel.pages.count)
          viewModel.currentPageIndex = current - 1
          withAnimation {
            scrollPosition = viewModel.currentPageIndex
            proxy.scrollTo(viewModel.currentPageIndex, anchor: .top)
          }
        } else if normalizedY > 0.65 {
          guard !viewModel.pages.isEmpty else { return }
          // Next page (bottom tap)
          viewModel.currentPageIndex = min(viewModel.currentPageIndex + 1, viewModel.pages.count)
          withAnimation {
            scrollPosition = viewModel.currentPageIndex
            proxy.scrollTo(viewModel.currentPageIndex, anchor: .top)
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
      proxy.scrollTo(target, anchor: .top)
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
