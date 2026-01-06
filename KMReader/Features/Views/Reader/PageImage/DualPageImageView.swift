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
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  init(
    viewModel: ReaderViewModel,
    firstPageIndex: Int,
    secondPageIndex: Int,
    screenSize: CGSize,
    isZoomed: Binding<Bool> = .constant(false)
  ) {
    self.viewModel = viewModel
    self.firstPageIndex = firstPageIndex
    self.secondPageIndex = secondPageIndex
    self.screenSize = screenSize
    self._isZoomed = isZoomed
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
    ZoomableImageContainer(
      screenSize: screenSize,
      resetID: resetID,
      doubleTapScale: doubleTapZoomScale,
      isZoomed: $isZoomed
    ) {
      HStack(spacing: 0) {
        pageView(
          index: firstPageIndex,
          alignment: .trailing
        )
        pageView(
          index: secondPageIndex,
          alignment: .leading
        )
      }
      .frame(width: screenSize.width, height: screenSize.height)
    }
  }

  @ViewBuilder
  private func pageView(
    index: Int,
    alignment: HorizontalAlignment
  ) -> some View {
    let frameAlignment = Alignment(horizontal: alignment, vertical: .center)
    PageImageView(
      viewModel: viewModel,
      pageIndex: index,
      alignment: alignment,
    )
    .frame(width: imageWidth, height: imageHeight, alignment: frameAlignment)
    .clipped()
  }
}
