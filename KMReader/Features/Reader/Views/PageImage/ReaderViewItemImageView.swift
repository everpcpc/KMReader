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
  let onPlayAnimatedPage: ((ReaderPageID) -> Void)?

  var body: some View {
    let pages = pageData

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
      .overlay {
        HStack(spacing: 0) {
          ForEach(Array(pages.enumerated()), id: \.offset) { _, data in
            pagePlaybackOverlay(for: data.pageID)
          }
        }
      }
    }
  }

  private var pageData: [NativePageData] {
    switch item {
    case .page(let id):
      return [makePageData(for: id, alignment: .center)]
    case .split(let id, let part):
      return [
        makePageData(
          for: id,
          alignment: .center,
          splitMode: splitMode(for: part)
        )
      ]
    case .dual(let first, let second):
      return [
        makePageData(for: first, alignment: .trailing),
        makePageData(for: second, alignment: .leading),
      ]
    case .end:
      return []
    }
  }

  private func makePageData(
    for pageID: ReaderPageID,
    alignment: HorizontalAlignment,
    splitMode: PageSplitMode = .none
  ) -> NativePageData {
    NativePageData(
      pageID: pageID,
      isLoading: viewModel.page(for: pageID) != nil && viewModel.preloadedImage(for: pageID) == nil,
      error: nil,
      alignment: alignment,
      splitMode: splitMode
    )
  }

  private func splitMode(for part: ReaderSplitPart) -> PageSplitMode {
    let isLeftHalf = viewModel.isLeftSplitHalf(
      part: part,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )
    return isLeftHalf ? .leftHalf : .rightHalf
  }

  @ViewBuilder
  private func pagePlaybackOverlay(for pageID: ReaderPageID) -> some View {
    ZStack {
      if let animatedFileURL = autoPlayAnimatedFileURL(for: pageID) {
        InlineAnimatedImageView(
          fileURL: animatedFileURL,
          poolSlot: animatedPoolSlot(for: pageID)
        )
      } else if viewModel.shouldShowAnimatedPlayButton(for: pageID) {
        AnimatedImagePlayButton {
          onPlayAnimatedPage?(pageID)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func autoPlayAnimatedFileURL(for pageID: ReaderPageID) -> URL? {
    #if os(tvOS)
      return nil
    #else
      guard isPlaybackActive else { return nil }
      guard renderConfig.autoPlayAnimatedImages else { return nil }
      return viewModel.animatedPlaybackFileURL(for: pageID)
    #endif
  }

  private func animatedPoolSlot(for pageID: ReaderPageID) -> Int {
    max(viewModel.pageIndex(for: pageID) ?? 0, 0) % 4
  }
}
