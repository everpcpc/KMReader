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
  @Binding var isZoomed: Bool

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  init(
    viewModel: ReaderViewModel,
    firstPageIndex: Int,
    secondPageIndex: Int,
    screenSize: CGSize,
    readingDirection: ReadingDirection = .ltr,
    isZoomed: Binding<Bool> = .constant(false),
    onNextPage: @escaping () -> Void = {},
    onPreviousPage: @escaping () -> Void = {},
    onToggleControls: @escaping () -> Void = {}
  ) {
    self.viewModel = viewModel
    self.firstPageIndex = firstPageIndex
    self.secondPageIndex = secondPageIndex
    self.screenSize = screenSize
    self.readingDirection = readingDirection
    self._isZoomed = isZoomed
    self.onNextPage = onNextPage
    self.onPreviousPage = onPreviousPage
    self.onToggleControls = onToggleControls
  }

  var imageWidth: CGFloat {
    screenSize.width / 2
  }

  var imageHeight: CGFloat {
    screenSize.height
  }

  var resetID: String {
    "\(firstPageIndex)-\(secondPageIndex)"
  }

  var body: some View {
    let page1 = firstPageIndex >= 0 && firstPageIndex < viewModel.pages.count ? viewModel.pages[firstPageIndex] : nil
    let image1 = page1 != nil ? viewModel.preloadedImages[page1!.number] : nil

    let page2 = secondPageIndex >= 0 && secondPageIndex < viewModel.pages.count ? viewModel.pages[secondPageIndex] : nil
    let image2 = page2 != nil ? viewModel.preloadedImages[page2!.number] : nil

    PageImageView(
      screenSize: screenSize,
      resetID: resetID,
      minScale: 1.0,
      maxScale: 8.0,
      doubleTapScale: doubleTapZoomScale,
      isZoomed: $isZoomed,
      readingDirection: readingDirection,
      onNextPage: onNextPage,
      onPreviousPage: onPreviousPage,
      onToggleControls: onToggleControls,
      pages: [
        NativePageData(
          bookId: viewModel.bookId,
          image: image1,
          pageNumber: firstPageIndex,
          isLoading: viewModel.isLoading && image1 == nil,
          error: nil,
          // Page 1 is always the first subview. In Dual Mode, the first subview always hugs the center spine (Trailing).
          // UIKit's Trailing automatically means Right in LTR and Left in RTL. Perfect.
          alignment: .trailing
        ),
        NativePageData(
          bookId: viewModel.bookId,
          image: image2,
          pageNumber: secondPageIndex,
          isLoading: viewModel.isLoading && image2 == nil,
          error: nil,
          // Page 2 is the second subview, it hugs the center spine (Leading).
          alignment: .leading
        ),
      ]
    )
  }
}
