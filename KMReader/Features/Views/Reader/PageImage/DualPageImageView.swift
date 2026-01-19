//
//  DualPageImageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Dual page image view with synchronized zoom and pan
struct DualPageImageView: View {
  var viewModel: ReaderViewModel
  let firstPageIndex: Int
  let secondPageIndex: Int
  let screenSize: CGSize

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  var resetID: String {
    "\(firstPageIndex)-\(secondPageIndex)"
  }

  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0
  @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast

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
  }
}
