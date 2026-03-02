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
    let isLoading = shouldShowAnimatedLoading(for: pageID)

    ZStack {
      if let animatedFileURL = animatedPlaybackFileURL(for: pageID) {
        LoopingVideoPlayerView(videoURL: animatedFileURL)
      }

      if isLoading {
        ProgressView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task(id: playbackTaskID(for: pageID)) {
      await prepareAnimatedPlaybackIfNeeded(for: pageID)
    }
  }

  private func animatedPlaybackFileURL(for pageID: ReaderPageID) -> URL? {
    #if os(tvOS)
      return nil
    #else
      guard isPlaybackActive else { return nil }
      return viewModel.animatedPlaybackFileURL(for: pageID)
    #endif
  }

  private func shouldShowAnimatedLoading(for pageID: ReaderPageID) -> Bool {
    #if os(tvOS)
      return false
    #else
      guard isPlaybackActive else { return false }
      return viewModel.isAnimatedPlaybackLoading(for: pageID)
    #endif
  }

  private func playbackTaskID(for pageID: ReaderPageID) -> String {
    "\(pageID.description)|\(isPlaybackActive ? "active" : "inactive")"
  }

  private func prepareAnimatedPlaybackIfNeeded(for pageID: ReaderPageID) async {
    #if os(tvOS)
      return
    #else
      guard isPlaybackActive else { return }
      await viewModel.focusAnimatedPlayback(for: item)
      guard viewModel.shouldPrepareAnimatedPlayback(for: pageID) else { return }
      guard viewModel.animatedPlaybackFileURL(for: pageID) == nil else { return }
      _ = await viewModel.prepareAnimatedPagePlaybackURL(pageID: pageID)
    #endif
  }
}
