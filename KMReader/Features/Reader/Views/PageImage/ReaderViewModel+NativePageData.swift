import SwiftUI

extension ReaderViewModel {
  func nativePageData(
    for item: ReaderViewItem,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode,
    pageTransitionStyle: PageTransitionStyle,
    isPlaybackActive: Bool
  ) -> [NativePageData] {
    switch item {
    case .page(let id):
      return [makeNativePageData(for: id, alignment: .center, isPlaybackActive: isPlaybackActive)]
    case .split(let id, let part):
      if part == .both {
        return splitPairNativePageData(
          for: id,
          readingDirection: readingDirection,
          splitWidePageMode: splitWidePageMode,
          isPlaybackActive: isPlaybackActive
        )
      }
      // For paged scroll transitions, anchor each half to its inner edge so the two halves
      // meet flush at the cell boundary when swiping across the spread. Cover / pageCurl /
      // none keep the legacy centered behavior to preserve the discrete-page metaphor.
      let alignment: HorizontalAlignment
      switch pageTransitionStyle {
      case .scroll:
        alignment = (part == .first) ? .trailing : .leading
      case .none, .cover, .pageCurl:
        alignment = .center
      }
      return [
        makeNativePageData(
          for: id,
          alignment: alignment,
          splitMode: nativeSplitMode(
            for: part,
            readingDirection: readingDirection,
            splitWidePageMode: splitWidePageMode
          ),
          isPlaybackActive: isPlaybackActive
        )
      ]
    case .dual(let first, let second):
      return [
        makeNativePageData(
          for: first,
          alignment: .trailing,
          isPlaybackActive: isPlaybackActive
        ),
        makeNativePageData(
          for: second,
          alignment: .leading,
          isPlaybackActive: isPlaybackActive
        ),
      ]
    case .end:
      return []
    }
  }

  private func splitPairNativePageData(
    for pageID: ReaderPageID,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode,
    isPlaybackActive: Bool
  ) -> [NativePageData] {
    let firstMode = nativeSplitMode(
      for: .first,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )
    let secondMode = nativeSplitMode(
      for: .second,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )

    return [
      makeNativePageData(
        for: pageID,
        alignment: .trailing,
        splitMode: firstMode,
        isPlaybackActive: isPlaybackActive
      ),
      makeNativePageData(
        for: pageID,
        alignment: .leading,
        splitMode: secondMode,
        isPlaybackActive: isPlaybackActive
      ),
    ]
  }

  private func nativeSplitMode(
    for part: ReaderSplitPart,
    readingDirection: ReadingDirection,
    splitWidePageMode: SplitWidePageMode
  ) -> PageSplitMode {
    let isLeftHalf = isLeftSplitHalf(
      part: part,
      readingDirection: readingDirection,
      splitWidePageMode: splitWidePageMode
    )
    return isLeftHalf ? .leftHalf : .rightHalf
  }

  private func makeNativePageData(
    for pageID: ReaderPageID,
    alignment: HorizontalAlignment,
    splitMode: PageSplitMode = .none,
    isPlaybackActive: Bool
  ) -> NativePageData {
    NativePageData(
      pageID: pageID,
      isLoading: page(for: pageID) != nil && preloadedImage(for: pageID) == nil,
      error: nil,
      alignment: alignment,
      splitMode: splitMode,
      animatedSourceFileURL: isPlaybackActive ? animatedSourceFileURL(for: pageID) : nil
    )
  }
}
