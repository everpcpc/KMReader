//
// WebtoonPageView.swift
//
//

#if os(iOS) || os(macOS)
  import SwiftUI

  struct WebtoonPageView: View {
    let viewModel: ReaderViewModel
    let readListContext: ReaderReadListContext?
    let onDismiss: () -> Void
    let toggleControls: () -> Void
    let pageWidthPercentage: Double
    let renderConfig: ReaderRenderConfig
    @State private var zoomTargetPageIndex: Int?
    @State private var zoomAnchor: CGPoint?
    @State private var zoomRequestID: UUID?

    func pageWidth(_ geometry: GeometryProxy) -> CGFloat {
      return geometry.size.width * (pageWidthPercentage / 100.0)
    }

    var body: some View {
      GeometryReader { geometry in
        ZStack {
          WebtoonReaderView(
            viewModel: viewModel,
            pageWidth: pageWidth(geometry),
            renderConfig: renderConfig,
            readListContext: readListContext,
            onDismiss: onDismiss,
            onPageChange: { pageIndex in
              viewModel.currentPageIndex = pageIndex
              viewModel.currentViewItemIndex = viewModel.viewItemIndex(forPageIndex: pageIndex)
            },
            onCenterTap: {
              toggleControls()
            },
            onZoomRequest: { pageIndex, anchor in
              openZoomOverlay(pageIndex: pageIndex, anchor: anchor)
            }
          )

          if let zoomTargetPageIndex, let zoomRequestID {
            WebtoonZoomOverlayView(
              viewModel: viewModel,
              pageIndex: zoomTargetPageIndex,
              zoomAnchor: zoomAnchor,
              zoomRequestID: zoomRequestID,
              renderConfig: renderConfig,
              onClose: {
                viewModel.isZoomed = false
                withAnimation(.easeInOut(duration: 0.2)) {
                  self.zoomTargetPageIndex = nil
                  self.zoomAnchor = nil
                  self.zoomRequestID = nil
                }
              }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(2)
          }
        }
      }
    }

    private func openZoomOverlay(pageIndex: Int, anchor: CGPoint) {
      guard zoomTargetPageIndex == nil else { return }
      guard pageIndex >= 0, pageIndex < viewModel.pageCount else { return }

      withAnimation(.easeInOut(duration: 0.2)) {
        zoomTargetPageIndex = pageIndex
        zoomAnchor = anchor
        zoomRequestID = UUID()
      }
      if viewModel.preloadedImage(forPageIndex: pageIndex) == nil {
        Task {
          await viewModel.preloadImageForPage(at: pageIndex)
        }
      }
    }
  }
#endif
