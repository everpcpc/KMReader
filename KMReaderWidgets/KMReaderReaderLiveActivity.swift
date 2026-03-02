//
//  KMReaderReaderLiveActivity.swift
//  KMReaderWidgets
//

import SwiftUI
import WidgetKit

#if os(iOS)
  import ActivityKit

  struct KMReaderReaderLiveActivity: Widget {
    var body: some WidgetConfiguration {
      ActivityConfiguration(for: ReaderActivityAttributes.self) { context in
        VStack(spacing: 10) {
          HStack(spacing: 10) {
            Image(systemName: context.state.readerKind.iconName)
              .font(.title3.weight(.semibold))
              .foregroundStyle(context.state.tintColor)
              .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
              Text(context.state.seriesTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(context.state.chapterTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
              Text(context.state.readerKind.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(context.state.statusTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(context.state.tintColor)
            }
          }

          Capsule()
            .fill(context.state.tintColor.opacity(0.3))
            .frame(height: 6)
            .overlay(alignment: .leading) {
              Capsule()
                .fill(context.state.tintColor)
                .frame(width: context.state.isReading ? 80 : 28, height: 6)
            }
            .animation(.easeInOut(duration: 0.25), value: context.state.isReading)
        }
        .padding(12)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.95))
        .activitySystemActionForegroundColor(.primary)

      } dynamicIsland: { context in
        DynamicIsland {
          DynamicIslandExpandedRegion(.leading) {
            Image(systemName: context.state.readerKind.iconName)
              .foregroundStyle(context.state.tintColor)
              .font(.title2)
          }
          DynamicIslandExpandedRegion(.trailing) {
            Text(context.state.statusShortTitle)
              .font(.caption.weight(.bold))
              .foregroundStyle(context.state.tintColor)
          }
          DynamicIslandExpandedRegion(.center) {
            VStack(spacing: 2) {
              Text(context.state.seriesTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(context.state.chapterTitle)
                .font(.caption)
                .lineLimit(1)
            }
          }
          DynamicIslandExpandedRegion(.bottom) {
            HStack(spacing: 6) {
              Text(context.state.readerKind.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              Circle()
                .fill(context.state.tintColor)
                .frame(width: 6, height: 6)
              Text(context.state.statusTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(context.state.tintColor)
            }
          }
        } compactLeading: {
          Image(systemName: context.state.readerKind.iconName)
            .foregroundStyle(context.state.tintColor)
        } compactTrailing: {
          Text(context.state.statusShortTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(context.state.tintColor)
        } minimal: {
          Image(systemName: context.state.readerKind.iconName)
            .foregroundStyle(context.state.tintColor)
        }
        .keylineTint(context.state.tintColor)
      }
    }
  }

  extension ReaderActivityAttributes.ContentState {
    fileprivate var isReading: Bool {
      sessionState == .reading
    }

    fileprivate var statusTitle: String {
      isReading ? "Reading" : "Closed"
    }

    fileprivate var statusShortTitle: String {
      isReading ? "ON" : "OFF"
    }

    fileprivate var tintColor: Color {
      isReading ? .green : .gray
    }
  }

  extension ReaderActivityAttributes.ReaderKind {
    fileprivate var label: String {
      switch self {
      case .divina:
        return "DIVINA"
      case .epub:
        return "EPUB"
      case .pdf:
        return "PDF"
      }
    }

    fileprivate var iconName: String {
      switch self {
      case .divina:
        return "book.pages"
      case .epub:
        return "character.book.closed"
      case .pdf:
        return "doc.richtext"
      }
    }
  }

  extension ReaderActivityAttributes {
    fileprivate static var preview: ReaderActivityAttributes {
      ReaderActivityAttributes(bookId: "preview-book-id")
    }
  }

  extension ReaderActivityAttributes.ContentState {
    fileprivate static var readingPreview: ReaderActivityAttributes.ContentState {
      ReaderActivityAttributes.ContentState(
        sessionState: .reading,
        readerKind: .divina,
        seriesTitle: "One Piece",
        chapterTitle: "#1058 - The Flame Emperor's Triumph"
      )
    }
  }

  #Preview("Reader Notification", as: .content, using: ReaderActivityAttributes.preview) {
    KMReaderReaderLiveActivity()
  } contentStates: {
    ReaderActivityAttributes.ContentState.readingPreview
  }
#endif
