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
    let page = pageIndex >= 0 && pageIndex < viewModel.pages.count ? viewModel.pages[pageIndex] : nil

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
          bookId: viewModel.bookId,
          pageNumber: pageIndex,
          isLoading: viewModel.isLoading && page != nil && viewModel.preloadedImages[pageIndex] == nil,
          error: nil,
          alignment: .center,
          splitMode: isLeftHalf ? .leftHalf : .rightHalf
        )
      ]
    )
    .frame(width: screenSize.width, height: screenSize.height)
    .overlay {
      if viewModel.shouldShowAnimatedPlayButton(for: pageIndex) {
        AnimatedImagePlayButton {
          onPlayAnimatedPage?(pageIndex)
        }
      }
    }
  }
}
