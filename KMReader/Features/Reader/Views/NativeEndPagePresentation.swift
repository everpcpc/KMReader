import CoreGraphics
import Foundation

struct NativeEndPagePresentation {
  enum SectionDisplayMode {
    case both
    case previousOnly
    case nextOnly
  }

  enum LayoutMode {
    case singlePrevious
    case singleNext
    case stacked
    case sideBySide(nextOnLeadingSide: Bool, showsRelationHeader: Bool)
  }

  struct Section {
    let isVisible: Bool
    let badgeText: String?
    let bookID: String?
    let title: String?
    let detail: String?
    let showsCover: Bool
    let showsMetadata: Bool
    let showsCaughtUp: Bool
  }

  let relationTitle: String
  let previous: Section
  let next: Section
  let showsCloseButton: Bool

  static func make(
    previousBook: Book?,
    nextBook: Book?,
    readListContext: ReaderReadListContext?,
    sectionDisplayMode: SectionDisplayMode = .both
  ) -> NativeEndPagePresentation {
    let relationTitle = readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle ?? ""
    let previousVisible = sectionDisplayMode != .nextOnly && previousBook != nil
    let nextVisible = sectionDisplayMode != .previousOnly

    let previousSection = Section(
      isVisible: previousVisible,
      badgeText: previousVisible ? String(localized: "reader.previousBook").uppercased() : nil,
      bookID: previousVisible ? previousBook?.id : nil,
      title: previousVisible ? previousBook?.readerChapterTitle : nil,
      detail: previousVisible ? previousBook?.readerChapterDetail : nil,
      showsCover: previousVisible,
      showsMetadata: previousVisible,
      showsCaughtUp: false
    )

    let nextSection = Section(
      isVisible: nextVisible,
      badgeText: nextBook != nil && nextVisible ? String(localized: "reader.nextBook").uppercased() : nil,
      bookID: nextVisible ? nextBook?.id : nil,
      title: nextVisible ? nextBook?.readerChapterTitle : nil,
      detail: nextVisible ? nextBook?.readerChapterDetail : nil,
      showsCover: nextBook != nil && nextVisible,
      showsMetadata: nextBook != nil && nextVisible,
      showsCaughtUp: nextBook == nil && nextVisible
    )

    return NativeEndPagePresentation(
      relationTitle: relationTitle,
      previous: previousSection,
      next: nextSection,
      showsCloseButton: nextSection.showsCaughtUp
    )
  }

  func layoutMode(for size: CGSize, readingDirection: ReadingDirection) -> LayoutMode {
    if previous.isVisible && next.isVisible {
      if size.height >= size.width {
        return .stacked
      }
      return .sideBySide(
        nextOnLeadingSide: readingDirection == .rtl,
        showsRelationHeader: !relationTitle.isEmpty
      )
    }

    if previous.isVisible {
      return .singlePrevious
    }

    return .singleNext
  }
}
