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
      if part == .both {
        return splitPairPageData(for: id)
      }
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

  private func splitPairPageData(for pageID: ReaderPageID) -> [NativePageData] {
    let firstIsLeftHalf = viewModel.isLeftSplitHalf(
      part: .first,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )
    let secondIsLeftHalf = viewModel.isLeftSplitHalf(
      part: .second,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )

    return [
      makePageData(
        for: pageID,
        alignment: .trailing,
        splitMode: firstIsLeftHalf ? .leftHalf : .rightHalf
      ),
      makePageData(
        for: pageID,
        alignment: .leading,
        splitMode: secondIsLeftHalf ? .leftHalf : .rightHalf
      ),
    ]
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
    if let sourceFileURL = animatedSourceFileURL(for: pageID) {
      AnimatedImagePlayerView(sourceFileURL: sourceFileURL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func animatedSourceFileURL(for pageID: ReaderPageID) -> URL? {
    #if os(tvOS)
      return nil
    #else
      guard isPlaybackActive else { return nil }
      return viewModel.animatedSourceFileURL(for: pageID)
    #endif
  }
}
