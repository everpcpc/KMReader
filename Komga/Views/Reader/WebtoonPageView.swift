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

  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("showTapZone") private var showTapZone: Bool = true
  @State private var showTapZoneOverlay = false

  var body: some View {
    GeometryReader { geometry in
      let pageWidth = geometry.size.width * (webtoonPageWidthPercentage / 100.0)
      let screenKey = "\(Int(geometry.size.width))x\(Int(geometry.size.height))"

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

        // Tap zone overlay
        if showTapZoneOverlay {
          WebtoonTapZoneOverlay()
        }
      }
      .onAppear {
        // Show tap zone overlay when view appears with pages loaded
        if showTapZone && !viewModel.pages.isEmpty && !showTapZoneOverlay {
          showTapZoneOverlay = true
        }
      }
      .onChange(of: viewModel.pages.count) { oldCount, newCount in
        // Show tap zone overlay when pages are first loaded
        if oldCount == 0 && newCount > 0 {
          triggerTapZoneDisplay()
        }
      }
      .onChange(of: screenKey) { _, _ in
        // Show tap zone overlay when screen orientation changes
        triggerTapZoneDisplay()
      }
    }
  }

  private func triggerTapZoneDisplay() {
    guard showTapZone && !viewModel.pages.isEmpty else { return }
    showTapZoneOverlay = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      showTapZoneOverlay = true
    }
  }
}
