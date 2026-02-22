//
// DualPageImageView.swift
//
//

import SwiftUI

// Dual page image view with synchronized zoom and pan
struct DualPageImageView: View {
  var viewModel: ReaderViewModel
  let firstPageIndex: Int
  let secondPageIndex: Int
  let screenSize: CGSize
  let renderConfig: ReaderRenderConfig

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void
  let onPlayAnimatedPage: ((Int) -> Void)?

  var resetID: String {
    "\(firstPageIndex)-\(secondPageIndex)"
  }

  var body: some View {
    let page1 = firstPageIndex >= 0 && firstPageIndex < viewModel.pages.count ? viewModel.pages[firstPageIndex] : nil
    let page2 = secondPageIndex >= 0 && secondPageIndex < viewModel.pages.count ? viewModel.pages[secondPageIndex] : nil

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: resetID,
      minScale: 1.0,
      maxScale: 8.0,
      readingDirection: readingDirection,
      renderConfig: renderConfig,
      onNextPage: onNextPage,
      onPreviousPage: onPreviousPage,
      onToggleControls: onToggleControls,
      pages: [
        NativePageData(
          bookId: viewModel.bookId,
          pageNumber: firstPageIndex,
          isLoading: viewModel.isLoading && page1 != nil && viewModel.preloadedImages[firstPageIndex] == nil,
          error: nil,
          // Page 1 is always the first subview. In Dual Mode, the first subview always hugs the center spine (Trailing).
          // UIKit's Trailing automatically means Right in LTR and Left in RTL. Perfect.
          alignment: .trailing
        ),
        NativePageData(
          bookId: viewModel.bookId,
          pageNumber: secondPageIndex,
          isLoading: viewModel.isLoading && page2 != nil && viewModel.preloadedImages[secondPageIndex] == nil,
          error: nil,
          // Page 2 is the second subview, it hugs the center spine (Leading).
          alignment: .leading
        ),
      ],
    )
    .frame(width: screenSize.width, height: screenSize.height)
    .overlay {
      HStack(spacing: 0) {
        pagePlayButton(for: firstPageIndex)
        pagePlayButton(for: secondPageIndex)
      }
    }
  }

  @ViewBuilder
  private func pagePlayButton(for pageIndex: Int) -> some View {
    ZStack {
      if let animatedFileURL = autoPlayAnimatedFileURL(for: pageIndex) {
        ReusableAnimatedImageWebView(
          fileURL: animatedFileURL,
          poolSlot: animatedPoolSlot(for: pageIndex)
        )
        .allowsHitTesting(false)
      } else if viewModel.shouldShowAnimatedPlayButton(for: pageIndex) {
        AnimatedImagePlayButton {
          onPlayAnimatedPage?(pageIndex)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func autoPlayAnimatedFileURL(for pageIndex: Int) -> URL? {
    #if os(tvOS)
      return nil
    #else
      guard renderConfig.autoPlayAnimatedImages else { return nil }
      return viewModel.animatedPlaybackFileURL(for: pageIndex)
    #endif
  }

  private func animatedPoolSlot(for pageIndex: Int) -> Int {
    max(pageIndex, 0) % 4
  }
}
