//
//  SinglePageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Single page image view with zoom and pan support
struct SinglePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  let screenSize: CGSize

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0

  var body: some View {
    let page = pageIndex >= 0 && pageIndex < viewModel.pages.count ? viewModel.pages[pageIndex] : nil

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: pageIndex,
      minScale: 1.0,
      maxScale: 8.0,
      readingDirection: readingDirection,
      doubleTapScale: CGFloat(doubleTapZoomScale),
      tapZoneSize: tapZoneSize,
      tapZoneMode: tapZoneMode,
      showPageNumber: showPageNumber,
      readerBackground: readerBackground,
      enableLiveText: enableLiveText,
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
  }
}
