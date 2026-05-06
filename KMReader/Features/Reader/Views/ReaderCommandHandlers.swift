import Foundation

typealias ReaderTapZoneTapHandler = (_ normalizedX: CGFloat, _ normalizedY: CGFloat) -> Void

struct ReaderCommandHandlers {
  let showReaderSettings: () -> Void
  let showBookDetails: () -> Void
  let showTableOfContents: () -> Void
  let showPageJump: () -> Void
  let showSearch: () -> Void
  let openPreviousBook: () -> Void
  let openNextBook: () -> Void
  let setReadingDirection: (ReadingDirection) -> Void
  let setPageLayout: (PageLayout) -> Void
  let toggleIsolateCoverPage: () -> Void
  let toggleIsolatePage: (ReaderPageID) -> Void
  let setSplitWidePageMode: (SplitWidePageMode) -> Void
  let toggleContinuousScroll: () -> Void
}
