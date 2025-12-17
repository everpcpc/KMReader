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
    @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false

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
          disableTapToTurnPage: disableTapToTurnPage,
          onPageChange: { pageIndex in
            viewModel.currentPageIndex = pageIndex
          },
          onCenterTap: {
            toggleControls()
          },
          onScrollToBottom: { atBottom in
            isAtBottom = atBottom
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
            onFocusChange: nil
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
