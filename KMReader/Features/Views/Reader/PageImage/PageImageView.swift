//
//  PageImageView.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  import UIKit
#endif

#if os(macOS)
  import AppKit
#endif

/// Data structure for a single page to be rendered natively
struct NativePageData {
  let bookId: String
  let pageNumber: Int
  let isLoading: Bool
  let error: String?
  let alignment: HorizontalAlignment
}

/// A high-performance page view entry point that calls platform-specific PageScrollView.
struct PageImageView: View {
  var viewModel: ReaderViewModel
  let screenSize: CGSize
  let resetID: AnyHashable
  let minScale: CGFloat
  let maxScale: CGFloat
  let doubleTapScale: CGFloat
  @Binding var isZoomed: Bool

  // Navigation Callbacks
  let readingDirection: ReadingDirection
  let onNextPage: () -> Void
  let onPreviousPage: () -> Void
  let onToggleControls: () -> Void

  // Content Data
  let pages: [NativePageData]

  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false

  var body: some View {
    PageScrollView(
      viewModel: viewModel,
      screenSize: screenSize,
      resetID: resetID,
      minScale: minScale,
      maxScale: maxScale,
      doubleTapScale: doubleTapScale,
      isZoomed: $isZoomed,
      tapZoneSize: tapZoneSize,
      disableTapToTurnPage: disableTapToTurnPage,
      showPageNumber: showPageNumber,
      readerBackground: readerBackground,
      readingDirection: readingDirection,
      enableLiveText: enableLiveText,
      onNextPage: onNextPage,
      onPreviousPage: onPreviousPage,
      onToggleControls: onToggleControls,
      pages: pages
    )
    .frame(width: screenSize.width, height: screenSize.height)
  }
}
