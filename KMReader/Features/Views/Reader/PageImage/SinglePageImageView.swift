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
  @Binding var isZoomed: Bool

  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  init(
    viewModel: ReaderViewModel,
    pageIndex: Int,
    screenSize: CGSize,
    readingDirection: ReadingDirection = .ltr,
    isZoomed: Binding<Bool> = .constant(false),
    onNextPage: @escaping () -> Void = {},
    onPreviousPage: @escaping () -> Void = {},
    onToggleControls: @escaping () -> Void = {}
  ) {
    self.viewModel = viewModel
    self.pageIndex = pageIndex
    self.screenSize = screenSize
    self.readingDirection = readingDirection
    self._isZoomed = isZoomed
    self.onNextPage = onNextPage
    self.onPreviousPage = onPreviousPage
    self.onToggleControls = onToggleControls
  }

  var body: some View {
    let page = pageIndex >= 0 && pageIndex < viewModel.pages.count ? viewModel.pages[pageIndex] : nil
    let image = page != nil ? viewModel.preloadedImages[page!.number] : nil

    PageImageView(
      screenSize: screenSize,
      resetID: pageIndex,
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
          image: image,
          pageNumber: pageIndex,
          isLoading: viewModel.isLoading && image == nil,
          error: nil,
          alignment: .center
        )
      ]
    )
  }
}
