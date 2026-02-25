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

  @Environment(\.readerBackgroundPreference) private var readerBackground
  @Environment(\.colorScheme) private var colorScheme

  init(
    previousBook: Book?,
    nextBook: Book?,
    readListContext: ReaderReadListContext?,
    onDismiss: @escaping () -> Void,
    readingDirection: ReadingDirection
  ) {
    self.previousBook = previousBook
    self.nextBook = nextBook
    self.readListContext = readListContext
    self.onDismiss = onDismiss
    self.readingDirection = readingDirection
  }

  private var textColor: Color {
    readerBackground.contentColor
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
      let minDimension = min(geometry.size.width, geometry.size.height)
      let contentPadding = clamped(minDimension * 0.08, lower: 20, upper: 56)
      let contentSpacing = clamped(minDimension * 0.04, lower: 14, upper: 28)
      let sectionSpacing = clamped(minDimension * 0.032, lower: 10, upper: 20)
      let portraitExtraDividerPadding = clamped(sectionSpacing * 0.5, lower: 6, upper: 12)
      let coverWidth = clamped(
        minDimension * (isPortrait ? 0.3 : 0.23),
        lower: 96,
        upper: 190
      )
      let coverHeight = coverWidth / CoverAspectRatio.widthToHeight
      let dividerHeight = clamped(geometry.size.height * 0.32, lower: 140, upper: 320)
      let dividerMaxWidth = clamped(geometry.size.width * 0.78, lower: 260, upper: 680)

      VStack(spacing: contentSpacing) {
        Group {
          if isPortrait {
            portraitContent(
              sectionSpacing: sectionSpacing,
              coverWidth: coverWidth,
              coverHeight: coverHeight,
              dividerMaxWidth: dividerMaxWidth,
              dividerVerticalPadding: portraitExtraDividerPadding
            )
          } else {
            landscapeContent(
              sectionSpacing: sectionSpacing,
              coverWidth: coverWidth,
              coverHeight: coverHeight,
              dividerHeight: dividerHeight
            )
          }
        }
        .allowsHitTesting(false)

        if nextBook == nil {
          Button {
            onDismiss()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "xmark")
                .font(.subheadline)
              Text("Close")
                .font(.body)
            }
            .padding(.horizontal, 4)
            .contentShape(.capsule)
          }
          .adaptiveButtonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(.primary)
        }
      }
      .padding(contentPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
  }

  private func portraitContent(
    sectionSpacing: CGFloat,
    coverWidth: CGFloat,
    coverHeight: CGFloat,
    dividerMaxWidth: CGFloat,
    dividerVerticalPadding: CGFloat
  ) -> some View {
    VStack(spacing: sectionSpacing) {
      chapterSection(
        label: String(localized: "reader.previousBook"),
        book: previousBook,
        showCover: false,
        isNextSection: false,
        alignment: .center,
        showLabel: true,
        sectionSpacing: sectionSpacing,
        coverWidth: coverWidth,
        coverHeight: coverHeight
      )

      relationDividerHorizontal(maxWidth: dividerMaxWidth)
        .padding(.vertical, dividerVerticalPadding)

      chapterSection(
        label: String(localized: "reader.nextBook"),
        book: nextBook,
        showCover: true,
        isNextSection: true,
        alignment: .center,
        showLabel: nextBook != nil,
        sectionSpacing: sectionSpacing,
        coverWidth: coverWidth,
        coverHeight: coverHeight
      )
    }
  }

  private func landscapeContent(
    sectionSpacing: CGFloat,
    coverWidth: CGFloat,
    coverHeight: CGFloat,
    dividerHeight: CGFloat
  ) -> some View {
    VStack(spacing: sectionSpacing) {
      if !relationTitle.isEmpty {
        Text(relationTitle)
          .font(.headline)
          .fontDesign(.rounded)
          .foregroundColor(textColor.opacity(0.85))
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }

      HStack(spacing: sectionSpacing) {
        if isForwardOnLeadingSide {
          chapterSection(
            label: String(localized: "reader.nextBook"),
            book: nextBook,
            showCover: true,
            isNextSection: true,
            alignment: .center,
            showLabel: nextBook != nil,
            sectionSpacing: sectionSpacing,
            coverWidth: coverWidth,
            coverHeight: coverHeight
          )
          relationDividerVertical(height: dividerHeight)
          chapterSection(
            label: String(localized: "reader.previousBook"),
            book: previousBook,
            showCover: true,
            isNextSection: false,
            alignment: .center,
            showLabel: true,
            sectionSpacing: sectionSpacing,
            coverWidth: coverWidth,
            coverHeight: coverHeight
          )
        } else {
          chapterSection(
            label: String(localized: "reader.previousBook"),
            book: previousBook,
            showCover: true,
            isNextSection: false,
            alignment: .center,
            showLabel: true,
            sectionSpacing: sectionSpacing,
            coverWidth: coverWidth,
            coverHeight: coverHeight
          )
          relationDividerVertical(height: dividerHeight)
          chapterSection(
            label: String(localized: "reader.nextBook"),
            book: nextBook,
            showCover: true,
            isNextSection: true,
            alignment: .center,
            showLabel: nextBook != nil,
            sectionSpacing: sectionSpacing,
            coverWidth: coverWidth,
            coverHeight: coverHeight
          )
        }
      }
    }
  }

  private func relationDividerHorizontal(maxWidth: CGFloat) -> some View {
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
    .frame(maxWidth: maxWidth)
  }

  private func relationDividerVertical(height: CGFloat) -> some View {
    Rectangle()
      .fill(textColor.opacity(0.3))
      .frame(width: 1, height: height)
  }

  @ViewBuilder
  private func chapterSection(
    label: String,
    book: Book?,
    showCover: Bool,
    isNextSection: Bool,
    alignment: HorizontalAlignment,
    showLabel: Bool,
    sectionSpacing: CGFloat,
    coverWidth: CGFloat,
    coverHeight: CGFloat
  ) -> some View {
    VStack(alignment: alignment, spacing: sectionSpacing) {
      if showLabel {
        Text(label.uppercased())
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(textColor.opacity(0.55))
          .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
      }

      if let book {
        if showCover {
          ThumbnailImage(
            id: book.id,
            type: .book,
            shadowStyle: .none,
            width: coverWidth,
            cornerRadius: coverCornerRadius(for: coverWidth)
          )
          .colorMultiply(readerBackground.appliesImageMultiplyBlend ? readerBackground.color : .white)
          .frame(width: coverWidth, height: coverHeight)
          .shadow(
            color: coverShadowColor,
            radius: clamped(coverWidth * 0.08, lower: 4, upper: 10),
            x: 0,
            y: clamped(coverWidth * 0.04, lower: 2, upper: 6)
          )
          .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
        }

        Text(chapterTitle(for: book))
          .font(coverWidth >= 150 ? .title2 : .title3)
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

  private var coverShadowColor: Color {
    switch readerBackground {
    case .black, .gray:
      return .white.opacity(0.16)
    case .white:
      return .black.opacity(0.18)
    case .sepia:
      return .black.opacity(0.14)
    case .system:
      return colorScheme == .dark ? .white.opacity(0.14) : .black.opacity(0.18)
    }
  }

  private func coverCornerRadius(for width: CGFloat) -> CGFloat {
    clamped(width * 0.1, lower: 10, upper: 16)
  }

  private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, lower), upper)
  }

}
