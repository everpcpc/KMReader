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
    let screenSize: CGSize
    let pageWidthPercentage: Double
    let readerBackground: ReaderBackground

    @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
    @AppStorage("showPageNumber") private var showPageNumber: Bool = true

    @State private var panUpdateHandler: ((CGFloat) -> Void)?
    @State private var panEndHandler: ((CGFloat) -> Void)?

    var pageWidth: CGFloat {
      return screenSize.width * (pageWidthPercentage / 100.0)
    }

    var body: some View {
      ZStack {
        WebtoonReaderView(
          pages: viewModel.pages,
          viewModel: viewModel,
          pageWidth: pageWidth,
          readerBackground: readerBackground,
          tapZoneMode: tapZoneMode,
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
            onFocusChange: nil,
            onExternalPanUpdate: { handler in
              panUpdateHandler = handler
            },
            onExternalPanEnd: { handler in
              panEndHandler = handler
            }
          )
          .padding(.bottom, WebtoonConstants.footerPadding)
          .frame(height: WebtoonConstants.footerHeight)
        }
        .opacity(isAtBottom ? 1 : 0)
        .allowsHitTesting(isAtBottom)
        .transition(.opacity)
      }
    }
  }
#endif
