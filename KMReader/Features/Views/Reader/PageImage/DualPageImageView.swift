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
  let isRTL: Bool
  @Binding var isZoomed: Bool
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  init(
    viewModel: ReaderViewModel,
    firstPageIndex: Int,
    secondPageIndex: Int,
    screenSize: CGSize,
    isRTL: Bool,
    isZoomed: Binding<Bool> = .constant(false)
  ) {
    self.viewModel = viewModel
    self.firstPageIndex = firstPageIndex
    self.secondPageIndex = secondPageIndex
    self.screenSize = screenSize
    self.isRTL = isRTL
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
        if isRTL {
          pageView(
            index: secondPageIndex,
            alignment: .trailing
          )
          pageView(
            index: firstPageIndex,
            alignment: .leading
          )
        } else {
          pageView(
            index: firstPageIndex,
            alignment: .trailing
          )
          pageView(
            index: secondPageIndex,
            alignment: .leading
          )
        }
      }
      .frame(width: screenSize.width, height: screenSize.height)
    }
  }

  private func pageNumberAlignment(for alignment: Alignment) -> Alignment {
    // For dual page: left page shows page number at top-leading, right page at top-trailing
    alignment == .trailing ? .topLeading : .topTrailing
  }

  @ViewBuilder
  private func pageView(
    index: Int,
    alignment: Alignment
  ) -> some View {
    PageImageView(
      viewModel: viewModel,
      pageIndex: index,
      pageNumberAlignment: pageNumberAlignment(for: alignment)
    )
    .frame(width: imageWidth, height: imageHeight, alignment: alignment)
    .clipped()
  }
}
