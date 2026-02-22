//
// SinglePageImageView.swift
//
//

import SwiftUI

// Single page image view with zoom and pan support
struct SinglePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  let screenSize: CGSize
  let renderConfig: ReaderRenderConfig

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void
  let onPlayAnimatedPage: ((Int) -> Void)?

  var body: some View {
    let page = pageIndex >= 0 && pageIndex < viewModel.pages.count ? viewModel.pages[pageIndex] : nil

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: pageIndex,
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
          pageNumber: pageIndex,
          isLoading: viewModel.isLoading && page != nil && viewModel.preloadedImages[pageIndex] == nil,
          error: nil,
          alignment: .center
        )
      ]
    )
    .frame(width: screenSize.width, height: screenSize.height)
    .overlay {
      if let animatedFileURL = autoPlayAnimatedFileURL {
        ReusableAnimatedImageWebView(
          fileURL: animatedFileURL,
          poolSlot: animatedPoolSlot
        )
        .allowsHitTesting(false)
      } else if viewModel.shouldShowAnimatedPlayButton(for: pageIndex) {
        AnimatedImagePlayButton {
          onPlayAnimatedPage?(pageIndex)
        }
      }
    }
  }

  private var autoPlayAnimatedFileURL: URL? {
    #if os(tvOS)
      return nil
    #else
      guard renderConfig.autoPlayAnimatedImages else { return nil }
      return viewModel.animatedPlaybackFileURL(for: pageIndex)
    #endif
  }

  private var animatedPoolSlot: Int {
    max(pageIndex, 0) % 4
  }
}
