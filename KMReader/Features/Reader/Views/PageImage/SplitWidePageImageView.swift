//
// SplitWidePageImageView.swift
//
//

import SwiftUI

// Split wide page image view - displays half of a wide page
struct SplitWidePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  let isLeftHalf: Bool  // true for left half, false for right half
  let screenSize: CGSize
  let renderConfig: ReaderRenderConfig

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void
  let onPlayAnimatedPage: ((Int) -> Void)?

  var body: some View {
    let readerPage = viewModel.readerPage(at: pageIndex)

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: "\(pageIndex)-\(isLeftHalf ? "left" : "right")",
      minScale: 1.0,
      maxScale: 8.0,
      readingDirection: readingDirection,
      renderConfig: renderConfig,
      onNextPage: onNextPage,
      onPreviousPage: onPreviousPage,
      onToggleControls: onToggleControls,
      pages: [
        NativePageData(
          bookId: viewModel.resolvedBookId(forPageIndex: pageIndex),
          pageNumber: pageIndex,
          isLoading: viewModel.isLoading && readerPage != nil
            && viewModel.preloadedImage(forPageIndex: pageIndex) == nil,
          error: nil,
          alignment: .center,
          splitMode: isLeftHalf ? .leftHalf : .rightHalf
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
