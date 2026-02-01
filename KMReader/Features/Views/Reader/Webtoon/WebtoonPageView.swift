//
//  WebtoonPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS) || os(macOS)
  import SwiftUI

  struct WebtoonPageView: View {
    let viewModel: ReaderViewModel
    @Binding var isAtBottom: Bool
    let nextBook: Book?
    let readList: ReadList?
    let onDismiss: () -> Void
    let onNextBook: (String) -> Void
    let toggleControls: () -> Void
    let pageWidthPercentage: Double
    let readerBackground: ReaderBackground

    @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
    @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast
    @AppStorage("showPageNumber") private var showPageNumber: Bool = true

    @State private var panUpdateHandler: ((CGFloat) -> Void)?
    @State private var panEndHandler: ((CGFloat) -> Void)?
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
            pages: viewModel.pages,
            viewModel: viewModel,
            pageWidth: pageWidth(geometry),
            readerBackground: readerBackground,
            tapZoneMode: tapZoneMode,
            doubleTapZoomMode: doubleTapZoomMode,
            showPageNumber: showPageNumber,
            onPageChange: { pageIndex in
              viewModel.currentPageIndex = pageIndex
            },
            onCenterTap: {
              toggleControls()
            },
            onScrollToBottom: { atBottom in
              isAtBottom = atBottom
            },
            onNextBookPanUpdate: { translation in
              panUpdateHandler?(translation)
            },
            onNextBookPanEnd: { translation in
              panEndHandler?(translation)
            },
            onZoomRequest: { pageIndex, anchor in
              openZoomOverlay(pageIndex: pageIndex, anchor: anchor)
            }
          )

          VStack {
            Spacer()
            EndPageView(
              viewModel: viewModel,
              nextBook: nextBook,
              readList: readList,
              onDismiss: onDismiss,
              onNextBook: onNextBook,
              readingDirection: .webtoon,
              onPreviousPage: {},
              onFocusChange: nil,
              onExternalPanUpdate: { handler in
                panUpdateHandler = handler
              },
              onExternalPanEnd: { handler in
                panEndHandler = handler
              },
              showImage: false
            )
            .padding(.bottom, WebtoonConstants.footerPadding)
            .frame(height: WebtoonConstants.footerHeight)
          }
          .opacity(isAtBottom ? 1 : 0)
          .allowsHitTesting(isAtBottom)
          .transition(.opacity)

          if let zoomTargetPageIndex, let zoomRequestID {
            WebtoonZoomOverlayView(
              viewModel: viewModel,
              pageIndex: zoomTargetPageIndex,
              zoomAnchor: zoomAnchor,
              zoomRequestID: zoomRequestID,
              readerBackground: readerBackground,
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
      guard pageIndex >= 0, pageIndex < viewModel.pages.count else { return }

      withAnimation(.easeInOut(duration: 0.2)) {
        zoomTargetPageIndex = pageIndex
        zoomAnchor = anchor
        zoomRequestID = UUID()
      }
      if viewModel.preloadedImages[pageIndex] == nil {
        let page = viewModel.pages[pageIndex]
        Task {
          await viewModel.preloadImageForPage(page)
        }
      }
    }
  }
#endif
