//
// SinglePageImageView.swift
//
//

import SwiftUI

// Single page image view with zoom and pan support
struct SinglePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  let isPlaybackActive: Bool
  let screenSize: CGSize
  let renderConfig: ReaderRenderConfig

  let readingDirection: ReadingDirection
  let onPlayAnimatedPage: ((Int) -> Void)?

  var body: some View {
    let readerPage = viewModel.readerPage(at: pageIndex)

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: pageIndex,
      minScale: 1.0,
      maxScale: 8.0,
      readingDirection: readingDirection,
      renderConfig: renderConfig,
      pages: [
        NativePageData(
          bookId: viewModel.resolvedBookId(forPageIndex: pageIndex),
          pageNumber: pageIndex,
          isLoading: readerPage != nil && viewModel.preloadedImage(forPageIndex: pageIndex) == nil,
          error: nil,
          alignment: .center
        )
      ]
    )
    .frame(width: screenSize.width, height: screenSize.height)
    .overlay {
      if let animatedFileURL = autoPlayAnimatedFileURL {
        InlineAnimatedImageView(
          fileURL: animatedFileURL,
          poolSlot: animatedPoolSlot
        )
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
      guard isPlaybackActive else { return nil }
      guard renderConfig.autoPlayAnimatedImages else { return nil }
      return viewModel.animatedPlaybackFileURL(for: pageIndex)
    #endif
  }

  private var animatedPoolSlot: Int {
    max(pageIndex, 0) % 4
  }
}
