//
// ReaderViewItemImageView.swift
//
//

import SwiftUI

struct ReaderViewItemImageView: View {
  @State private var animatedLoadingProgress: [ReaderPageID: Double] = [:]

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
    let isLoading = shouldShowAnimatedLoading(for: pageID)
    let progress = animatedLoadingProgress[pageID]

    ZStack {
      if let animatedFileURL = animatedPlaybackFileURL(for: pageID) {
        LoopingVideoPlayerView(videoURL: animatedFileURL)
      }

      if isLoading {
        if let progress {
          VStack(spacing: 8) {
            ProgressView(value: progress, total: 1)
              .frame(maxWidth: 120)
            Text("\(Int((progress * 100).rounded()))%")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .padding(10)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        } else {
          ProgressView()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task(id: playbackTaskID(for: pageID)) {
      await monitorAnimatedPlayback(for: pageID)
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

  private func monitorAnimatedPlayback(for pageID: ReaderPageID) async {
    #if os(tvOS)
      await setAnimatedLoadingProgress(nil, for: pageID)
      return
    #else
      guard isPlaybackActive else {
        await setAnimatedLoadingProgress(nil, for: pageID)
        return
      }

      await viewModel.focusAnimatedPlayback(for: item)
      guard viewModel.shouldPrepareAnimatedPlayback(for: pageID) else {
        await setAnimatedLoadingProgress(nil, for: pageID)
        return
      }
      guard viewModel.animatedPlaybackFileURL(for: pageID) == nil else {
        await setAnimatedLoadingProgress(nil, for: pageID)
        return
      }

      let transcodeTask = Task {
        await viewModel.prepareAnimatedPagePlaybackURL(pageID: pageID)
      }
      var hasEnteredLoadingPhase = false

      while !Task.isCancelled {
        guard isPlaybackActive else { break }
        if viewModel.animatedPlaybackFileURL(for: pageID) != nil { break }

        let isLoading = viewModel.isAnimatedPlaybackLoading(for: pageID)
        if isLoading {
          hasEnteredLoadingPhase = true
        }

        let progress = await viewModel.animatedPlaybackProgress(for: pageID)
        if let progress {
          await setAnimatedLoadingProgress(progress, for: pageID)
        } else if isLoading || !hasEnteredLoadingPhase {
          await setAnimatedLoadingProgress(0, for: pageID)
        } else {
          break
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
      }

      if Task.isCancelled || !isPlaybackActive {
        transcodeTask.cancel()
      } else {
        _ = await transcodeTask.value
      }
      await setAnimatedLoadingProgress(nil, for: pageID)
    #endif
  }

  private func setAnimatedLoadingProgress(_ progress: Double?, for pageID: ReaderPageID) async {
    await MainActor.run {
      withAnimation(.linear(duration: 0.12)) {
        guard let progress else {
          animatedLoadingProgress.removeValue(forKey: pageID)
          return
        }
        animatedLoadingProgress[pageID] = min(max(progress, 0), 1)
      }
    }
  }
}
