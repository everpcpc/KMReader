//
//  WebtoonPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct WebtoonPageView: View {
  let viewModel: ReaderViewModel
  @Binding var currentPage: Int
  @Binding var isAtBottom: Bool
  let nextBook: Book?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let toggleControls: () -> Void
  let screenSize: CGSize

  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0

  var body: some View {
    let pageWidth = screenSize.width * (webtoonPageWidthPercentage / 100.0)

    ZStack {
      WebtoonReaderView(
        pages: viewModel.pages,
        currentPage: $currentPage,
        viewModel: viewModel,
        pageWidth: pageWidth,
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

      if isAtBottom {
        VStack {
          Spacer()
          EndPageView(
            nextBook: nextBook,
            onDismiss: onDismiss,
            onNextBook: onNextBook,
            isRTL: false,
          )
          .padding(.bottom, 160)
        }
        .transition(.opacity)
      }
    }
  }
}
