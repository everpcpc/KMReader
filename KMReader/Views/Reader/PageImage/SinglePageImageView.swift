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

  var body: some View {
    ZoomableImageContainer(screenSize: screenSize, resetID: pageIndex) {
      PageImageView(viewModel: viewModel, pageIndex: pageIndex)
        .reportZoomableContentSize()
        .frame(width: screenSize.width, height: screenSize.height, alignment: .center)
    }
  }
}
