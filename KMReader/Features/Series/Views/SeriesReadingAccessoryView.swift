//
// SeriesReadingAccessoryView.swift
//
//

#if os(iOS)
  import SwiftUI

  /// Content of the iOS 26.1 tab bar bottom accessory that surfaces the current
  /// series' continue-reading action. Laid out like the platform mini player:
  /// cover on the left, titles in the middle, action icon on the trailing edge.
  /// The system renders it as interactive glass and morphs it with tab bar
  /// minimize on scroll.
  @available(iOS 26.1, *)
  struct SeriesReadingAccessoryView: View {
    let presentation: ReadingActionBarContext.Presentation
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        HStack(spacing: 10) {
          CircularThumbnailImage(
            id: presentation.bookId ?? presentation.seriesId,
            type: presentation.bookId != nil ? .book : .series,
            diameter: 32
          )

          VStack(alignment: .leading, spacing: 1) {
            Text(presentation.title)
              .font(.callout.weight(.semibold))
              .lineLimit(1)

            Text(presentation.caption)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          Spacer(minLength: 8)

          if presentation.isResolving {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "book.fill")
              .font(.title3)
              .foregroundStyle(Color.accentColor)
              .padding(.horizontal, 8)
          }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("\(presentation.caption), \(presentation.title)"))
    }
  }
#endif
