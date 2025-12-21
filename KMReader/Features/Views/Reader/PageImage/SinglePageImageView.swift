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
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  init(
    viewModel: ReaderViewModel,
    pageIndex: Int,
    screenSize: CGSize,
    isZoomed: Binding<Bool> = .constant(false)
  ) {
    self.viewModel = viewModel
    self.pageIndex = pageIndex
    self.screenSize = screenSize
    self._isZoomed = isZoomed
  }

  var body: some View {
    ZoomableImageContainer(
      screenSize: screenSize,
      resetID: pageIndex,
      doubleTapScale: doubleTapZoomScale,
      isZoomed: $isZoomed
    ) {
      PageImageView(viewModel: viewModel, pageIndex: pageIndex)
        .frame(width: screenSize.width, height: screenSize.height, alignment: .center)
    }
  }
}
