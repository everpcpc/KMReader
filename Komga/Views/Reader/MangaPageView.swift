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

  @State private var hasSyncedInitialScroll = false
  @State private var showTapZoneOverlay = false
  @State private var scrollPosition: Int?
  @AppStorage("showTapZone") private var showTapZone: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

  var body: some View {
    GeometryReader { screenGeometry in
      let screenKey =
        "\(Int(screenGeometry.size.width))x\(Int(screenGeometry.size.height))"

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
              .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
              .contentShape(Rectangle())
              .simultaneousGesture(
                horizontalTapGesture(width: screenGeometry.size.width, proxy: proxy)
              )
              .id(viewModel.pages.count)

              // Pages in reverse order for RTL (last to first)
              ForEach((0..<viewModel.pages.count).reversed(), id: \.self) { pageIndex in
                PageImageView(viewModel: viewModel, pageIndex: pageIndex)
                  .frame(width: screenGeometry.size.width, height: screenGeometry.size.height)
                  .contentShape(Rectangle())
                  .simultaneousGesture(
                    horizontalTapGesture(width: screenGeometry.size.width, proxy: proxy)
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
          MangaTapZoneOverlay()
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
