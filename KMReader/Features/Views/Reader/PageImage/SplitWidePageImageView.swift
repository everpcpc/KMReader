//
//  SplitWidePageImageView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

// Split wide page image view - displays half of a wide page
struct SplitWidePageImageView: View {
  var viewModel: ReaderViewModel
  let pageIndex: Int
  let isLeftHalf: Bool  // true for left half, false for right half
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
  @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast

  var body: some View {
    let page = pageIndex >= 0 && pageIndex < viewModel.pages.count ? viewModel.pages[pageIndex] : nil

    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: "\(pageIndex)-\(isLeftHalf ? "left" : "right")",
      minScale: 1.0,
      maxScale: 8.0,
      readingDirection: readingDirection,
      doubleTapScale: CGFloat(doubleTapZoomScale),
      doubleTapZoomMode: doubleTapZoomMode,
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
          alignment: .center,
          splitMode: isLeftHalf ? .leftHalf : .rightHalf
        )
      ]
    )
    .frame(width: screenSize.width, height: screenSize.height)
  }
}
