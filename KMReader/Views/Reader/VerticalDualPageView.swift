//
//  VerticalDualPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct VerticalDualPageView: View {
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
  @State private var isZoomed = false

  #if os(tvOS)
    @FocusState private var navigationFocused: Bool
  #endif

  var body: some View {
    ZStack {
      ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(viewModel.pagePairs, id: \.self) { pagePair in
            Group {
              if pagePair.first == viewModel.pages.count {
                // End page
                ZStack {
                  readerBackground.color.ignoresSafeArea()
                  EndPageView(
                    nextBook: nextBook,
                    onDismiss: onDismiss,
                    onNextBook: onNextBook,
                    isRTL: false,
                    goToPreviousPage: goToPreviousPage
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
            .contentShape(Rectangle())
            #if os(iOS)
              .simultaneousGesture(
                verticalTapGesture(height: screenSize.height, proxy: proxy)
              )
            #endif
            .id(pagePair.first)
          }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
        .scrollDisabled(isZoomed)
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
            withAnimation(ReaderAnimations.pageTurn) {
              scrollPosition = targetPair.first
              proxy.scrollTo(targetPair.first, anchor: .top)
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

      #if os(tvOS)
        // Hidden navigation overlay
        Color.clear
          .frame(width: screenSize.width, height: screenSize.height)
          .contentShape(Rectangle())
          .focusable(viewModel.currentPageIndex < viewModel.pages.count)
          .focused($navigationFocused)
          .allowsHitTesting(viewModel.currentPageIndex < viewModel.pages.count)
          .onMoveCommand { direction in
            switch direction {
            case .up:
              goToPreviousPage()
            case .down:
              goToNextPage()
            default:
              break
            }
          }
          .onChange(of: viewModel.currentPageIndex) { _, newIndex in
            // When at endpage, remove focus to allow EndPageView buttons to get focus
            if newIndex >= viewModel.pages.count {
              navigationFocused = false
            } else if !navigationFocused {
              // When leaving endpage, restore focus
              navigationFocused = true
            }
          }
          .onAppear {
            if viewModel.currentPageIndex < viewModel.pages.count {
              navigationFocused = true
            }
          }
      #endif
    }
  }

  #if os(iOS)
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
            let currentPair = viewModel.dualPageIndices[viewModel.currentPageIndex]
            guard let currentPair = currentPair else { return }
            viewModel.targetPageIndex = max(0, currentPair.first - 1)
          } else if normalizedY > 0.7 {
            guard !viewModel.pages.isEmpty else { return }

            // Next page (bottom tap)
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
      proxy.scrollTo(dualPageIndex.first, anchor: .top)
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
