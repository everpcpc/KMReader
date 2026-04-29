//
// ReaderViewItemImageView.swift
//
//

import SwiftUI

struct ReaderViewItemImageView: View {
  var viewModel: ReaderViewModel
  let item: ReaderViewItem
  let isPlaybackActive: Bool
  let screenSize: CGSize
  let renderConfig: ReaderRenderConfig
  let readingDirection: ReadingDirection
  let splitWidePageMode: SplitWidePageMode

  var body: some View {
    let pages = viewModel.nativePageData(
      for: item,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode,
      isPlaybackActive: isPlaybackActive
    )

    if pages.isEmpty {
      EmptyView()
    } else {
      PageScrollView(
        viewModel: viewModel,
        screenSize: screenSize,
        resetID: item,
        minScale: 1.0,
        maxScale: 8.0,
        readingDirection: readingDirection,
        renderConfig: renderConfig,
        pages: pages
      )
      .frame(width: screenSize.width, height: screenSize.height)
    }
  }
}
