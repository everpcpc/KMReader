//
// WebtoonZoomOverlayView.swift
//
//

#if os(iOS) || os(macOS)
  import SwiftUI

  struct WebtoonZoomOverlayView: View {
    @Bindable var viewModel: ReaderViewModel
    let pageIndex: Int
    let zoomAnchor: CGPoint?
    let zoomRequestID: UUID
    let renderConfig: ReaderRenderConfig
    let onClose: () -> Void

    @State private var hasZoomedIn = false

    private var zoomRenderConfig: ReaderRenderConfig {
      ReaderRenderConfig(
        tapZoneSize: renderConfig.tapZoneSize,
        tapZoneMode: .none,
        showPageNumber: renderConfig.showPageNumber,
        autoPlayAnimatedImages: renderConfig.autoPlayAnimatedImages,
        readerBackground: renderConfig.readerBackground,
        enableLiveText: renderConfig.enableLiveText,
        doubleTapZoomScale: renderConfig.doubleTapZoomScale,
        doubleTapZoomMode: renderConfig.doubleTapZoomMode
      )
    }

    var body: some View {
      GeometryReader { geometry in
        let initialScale = CGFloat(zoomRenderConfig.doubleTapZoomScale)

        PageScrollView(
          viewModel: viewModel,
          screenSize: geometry.size,
          resetID: zoomRequestID,
          minScale: 1.0,
          maxScale: 8.0,
          displayMode: .fillWidth,
          readingDirection: .webtoon,
          renderConfig: zoomRenderConfig,
          initialZoomScale: initialScale,
          initialZoomAnchor: zoomAnchor,
          initialZoomID: zoomRequestID,
          onNextPage: {},
          onPreviousPage: {},
          onToggleControls: {},
          pages: [
            NativePageData(
              bookId: viewModel.resolvedBookId(forPageIndex: pageIndex),
              pageNumber: pageIndex,
              isLoading: viewModel.isLoading && viewModel.preloadedImage(forPageIndex: pageIndex) == nil,
              error: nil,
              alignment: .center
            )
          ]
        )
      }
      .background(renderConfig.readerBackground.color.readerIgnoresSafeArea())
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
