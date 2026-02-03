//
//  WebtoonZoomOverlayView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS) || os(macOS)
  import SwiftUI

  struct WebtoonZoomOverlayView: View {
    @Bindable var viewModel: ReaderViewModel
    let pageIndex: Int
    let zoomAnchor: CGPoint?
    let zoomRequestID: UUID
    let readerBackground: ReaderBackground
    let onClose: () -> Void

    @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0
    @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast
    @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
    @AppStorage("showPageNumber") private var showPageNumber: Bool = true
    @AppStorage("enableLiveText") private var enableLiveText: Bool = false

    @State private var hasZoomedIn = false

    var body: some View {
      GeometryReader { geometry in
        let initialScale = CGFloat(doubleTapZoomScale)

        PageScrollView(
          viewModel: viewModel,
          screenSize: geometry.size,
          resetID: zoomRequestID,
          minScale: 1.0,
          maxScale: 8.0,
          displayMode: .fillWidth,
          readingDirection: .webtoon,
          doubleTapScale: CGFloat(doubleTapZoomScale),
          doubleTapZoomMode: doubleTapZoomMode,
          tapZoneSize: tapZoneSize,
          tapZoneMode: .none,
          showPageNumber: showPageNumber,
          readerBackground: readerBackground,
          enableLiveText: enableLiveText,
          initialZoomScale: initialScale,
          initialZoomAnchor: zoomAnchor,
          initialZoomID: zoomRequestID,
          onNextPage: {},
          onPreviousPage: {},
          onToggleControls: {},
          pages: [
            NativePageData(
              bookId: viewModel.bookId,
              pageNumber: pageIndex,
              isLoading: viewModel.isLoading && viewModel.preloadedImages[pageIndex] == nil,
              error: nil,
              alignment: .center
            )
          ]
        )
      }
      .background(readerBackground.color.readerIgnoresSafeArea())
      .readerIgnoresSafeArea()
      .onChange(of: viewModel.isZoomed) { _, isZoomed in
        if isZoomed {
          hasZoomedIn = true
        } else if hasZoomedIn {
          onClose()
        }
      }
    }
  }
#endif
