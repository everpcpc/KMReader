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

  @Environment(\.zoomableContentSizeReporter) private var reportContentSize

  @State private var leftPageSize: CGSize = .zero
  @State private var rightPageSize: CGSize = .zero

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
    ZoomableImageContainer(screenSize: screenSize, resetID: resetID) {
      HStack(spacing: 0) {
        if isRTL {
          pageView(
            index: secondPageIndex,
            alignment: .trailing,
            update: updateLeftPageSize
          )
          pageView(
            index: firstPageIndex,
            alignment: .leading,
            update: updateRightPageSize
          )
        } else {
          pageView(
            index: firstPageIndex,
            alignment: .trailing,
            update: updateLeftPageSize
          )
          pageView(
            index: secondPageIndex,
            alignment: .leading,
            update: updateRightPageSize
          )
        }
      }
      .frame(width: screenSize.width, height: screenSize.height)
    }
  }

  private func updateLeftPageSize(_ size: CGSize) {
    leftPageSize = size
    reportCombinedSize()
  }

  private func updateRightPageSize(_ size: CGSize) {
    rightPageSize = size
    reportCombinedSize()
  }

  @ViewBuilder
  private func pageView(
    index: Int,
    alignment: Alignment,
    update: @escaping (CGSize) -> Void
  ) -> some View {
    PageImageView(viewModel: viewModel, pageIndex: index)
      .reportSize(update)
      .frame(width: imageWidth, height: imageHeight, alignment: alignment)
      .clipped()
  }

  private func reportCombinedSize() {
    let combinedWidth =
      effectiveDimension(leftPageSize.width, fallback: imageWidth)
      + effectiveDimension(rightPageSize.width, fallback: imageWidth)
    let combinedHeight = max(
      effectiveDimension(leftPageSize.height, fallback: imageHeight),
      effectiveDimension(rightPageSize.height, fallback: imageHeight)
    )
    let combined = CGSize(width: combinedWidth, height: combinedHeight)
    guard combined.width > 0 && combined.height > 0 else { return }
    reportContentSize(combined)
  }

  private func effectiveDimension(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
    value > 0 ? value : fallback
  }
}
