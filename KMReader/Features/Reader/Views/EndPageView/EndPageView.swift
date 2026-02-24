//
// EndPageView.swift
//
//

import SwiftUI

struct EndPageView: View {
  let previousBook: Book?
  let nextBook: Book?
  let readListContext: ReaderReadListContext?
  let onDismiss: () -> Void
  let readingDirection: ReadingDirection
  let renderConfig: ReaderRenderConfig?
  let onNextPage: (() -> Void)?
  let onPreviousPage: (() -> Void)?
  let onToggleControls: (() -> Void)?

  @Environment(\.readerBackgroundPreference) private var readerBackground

  init(
    previousBook: Book?,
    nextBook: Book?,
    readListContext: ReaderReadListContext?,
    onDismiss: @escaping () -> Void,
    readingDirection: ReadingDirection,
    renderConfig: ReaderRenderConfig? = nil,
    onNextPage: (() -> Void)? = nil,
    onPreviousPage: (() -> Void)? = nil,
    onToggleControls: (() -> Void)? = nil
  ) {
    self.previousBook = previousBook
    self.nextBook = nextBook
    self.readListContext = readListContext
    self.onDismiss = onDismiss
    self.readingDirection = readingDirection
    self.renderConfig = renderConfig
    self.onNextPage = onNextPage
    self.onPreviousPage = onPreviousPage
    self.onToggleControls = onToggleControls
  }

  private var textColor: Color {
    switch readerBackground {
    case .black:
      return .white
    case .white:
      return .black
    case .gray:
      return .white
    case .system:
      return .primary
    }
  }

  private var relationTitle: String {
    readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle ?? ""
  }

  private var isForwardOnLeadingSide: Bool {
    readingDirection == .rtl
  }

  var body: some View {
    GeometryReader { geometry in
      let isPortrait = geometry.size.height >= geometry.size.width

      VStack(spacing: 20) {
        Group {
          if isPortrait {
            portraitContent
          } else {
            landscapeContent
          }
        }
        .allowsHitTesting(false)

        if nextBook == nil {
          Button {
            onDismiss()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "xmark")
              Text("Close")
            }
            .padding(.horizontal, 4)
            .contentShape(.capsule)
          }
          .adaptiveButtonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(.primary)
        }
      }
      .padding(40)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      #if !os(tvOS)
        .simultaneousGesture(
          SpatialTapGesture().onEnded { value in
            handleTap(at: value.location, size: geometry.size)
          },
          including: .gesture
        )
      #endif
    }
  }

  private func handleTap(at location: CGPoint, size: CGSize) {
    guard let renderConfig else { return }
    guard size.width > 0, size.height > 0 else { return }

    let normalizedX = location.x / size.width
    let normalizedY = location.y / size.height
    let action = TapZoneHelper.action(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      tapZoneMode: renderConfig.tapZoneMode,
      readingDirection: readingDirection,
      zoneThreshold: renderConfig.tapZoneSize.value
    )

    switch action {
    case .previous:
      onPreviousPage?()
    case .next:
      onNextPage?()
    case .toggleControls:
      onToggleControls?()
    }
  }

  private var portraitContent: some View {
    VStack(spacing: 20) {
      chapterSection(
        label: String(localized: "reader.previousBook"),
        book: previousBook,
        showCover: false,
        isNextSection: false,
        alignment: .center
      )

      relationDividerHorizontal

      chapterSection(
        label: String(localized: "reader.nextBook"),
        book: nextBook,
        showCover: true,
        isNextSection: true,
        alignment: .center
      )
    }
  }

  private var landscapeContent: some View {
    VStack(spacing: 18) {
      if !relationTitle.isEmpty {
        Text(relationTitle)
          .font(.headline)
          .fontDesign(.rounded)
          .foregroundColor(textColor.opacity(0.85))
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }

      HStack(spacing: 20) {
        if isForwardOnLeadingSide {
          chapterSection(
            label: String(localized: "reader.nextBook"),
            book: nextBook,
            showCover: true,
            isNextSection: true,
            alignment: .center
          )
          relationDividerVertical
          chapterSection(
            label: String(localized: "reader.previousBook"),
            book: previousBook,
            showCover: true,
            isNextSection: false,
            alignment: .center
          )
        } else {
          chapterSection(
            label: String(localized: "reader.previousBook"),
            book: previousBook,
            showCover: true,
            isNextSection: false,
            alignment: .center
          )
          relationDividerVertical
          chapterSection(
            label: String(localized: "reader.nextBook"),
            book: nextBook,
            showCover: true,
            isNextSection: true,
            alignment: .center
          )
        }
      }
    }
  }

  private var relationDividerHorizontal: some View {
    HStack(spacing: 10) {
      Rectangle()
        .fill(textColor.opacity(0.3))
        .frame(height: 1)
      if !relationTitle.isEmpty {
        Text(relationTitle)
          .font(.caption)
          .foregroundColor(textColor.opacity(0.8))
          .lineLimit(1)
      }
      Rectangle()
        .fill(textColor.opacity(0.3))
        .frame(height: 1)
    }
    .frame(maxWidth: 520)
  }

  private var relationDividerVertical: some View {
    Rectangle()
      .fill(textColor.opacity(0.3))
      .frame(width: 1, height: 220)
  }

  @ViewBuilder
  private func chapterSection(
    label: String,
    book: Book?,
    showCover: Bool,
    isNextSection: Bool,
    alignment: HorizontalAlignment
  ) -> some View {
    VStack(alignment: alignment, spacing: 8) {
      Text(label.uppercased())
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(textColor.opacity(0.55))
        .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))

      if let book {
        if showCover {
          ThumbnailImage(
            id: book.id,
            type: .book,
            shadowStyle: .basic,
            width: 120,
            cornerRadius: 12
          )
          .frame(maxHeight: 160)
          .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
        }

        Text(chapterTitle(for: book))
          .font(.title3)
          .fontDesign(.serif)
          .fontWeight(.bold)
          .foregroundColor(textColor)
          .multilineTextAlignment(textAlignment(alignment))
          .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))

        Text(chapterDetail(for: book))
          .font(.caption)
          .foregroundColor(textColor.opacity(0.6))
          .multilineTextAlignment(textAlignment(alignment))
          .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
      } else if isNextSection {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
          Text(String(localized: "You're all caught up!"))
        }
        .font(.headline)
        .foregroundColor(textColor)
        .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
      }
    }
    .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
  }

  private func chapterTitle(for book: Book) -> String { book.readerChapterTitle }

  private func chapterDetail(for book: Book) -> String { book.readerChapterDetail }

  private func frameAlignment(_ alignment: HorizontalAlignment) -> Alignment {
    switch alignment {
    case .leading:
      return .leading
    case .trailing:
      return .trailing
    default:
      return .center
    }
  }

  private func textAlignment(_ alignment: HorizontalAlignment) -> TextAlignment {
    switch alignment {
    case .leading:
      return .leading
    case .trailing:
      return .trailing
    default:
      return .center
    }
  }

}
