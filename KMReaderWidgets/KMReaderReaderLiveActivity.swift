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
              if let seriesTitle = context.state.displaySeriesTitle {
                Text(seriesTitle)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Text(context.state.chapterTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
              Text(context.state.readerKind.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
              trailingStatusView(for: context.state)
            }
          }

          progressBar(for: context.state)
        }
        .padding(12)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.95))
        .activitySystemActionForegroundColor(.primary)

      } dynamicIsland: { context in
        DynamicIsland {
          DynamicIslandExpandedRegion(.leading) {
            HStack(spacing: 0) {
              Image(systemName: context.state.readerKind.iconName)
                .foregroundStyle(context.state.tintColor)
                .font(.title2)
              Spacer(minLength: 0)
            }
            .padding(.leading, 12)
          }
          DynamicIslandExpandedRegion(.trailing) {
            HStack(spacing: 0) {
              Spacer(minLength: 0)
              trailingStatusView(for: context.state)
            }
            .padding(.trailing, 12)
          }
          DynamicIslandExpandedRegion(.center) {
            expandedTitleView(for: context.state)
          }
          DynamicIslandExpandedRegion(.bottom) {
            progressBar(for: context.state)
              .padding(.horizontal, 12)
          }
        } compactLeading: {
          Image(systemName: context.state.readerKind.iconName)
            .foregroundStyle(context.state.tintColor)
        } compactTrailing: {
          compactTrailingStatusView(for: context.state)
        } minimal: {
          Image(systemName: context.state.readerKind.iconName)
            .foregroundStyle(context.state.tintColor)
        }
        .keylineTint(context.state.tintColor)
      }
    }

    @ViewBuilder
    private func trailingStatusView(for state: ReaderActivityAttributes.ContentState) -> some View {
      if state.isIncognitoSession {
        Image(systemName: "eye.slash.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(state.tintColor)
      } else {
        Text(state.progressText)
          .font(.caption.weight(.semibold))
          .foregroundStyle(state.tintColor)
      }
    }

    @ViewBuilder
    private func compactTrailingStatusView(for state: ReaderActivityAttributes.ContentState) -> some View {
      if state.isIncognitoSession {
        Image(systemName: "eye.slash.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(state.tintColor)
      } else {
        Text(state.progressText)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(state.tintColor)
      }
    }

    private func progressBar(for state: ReaderActivityAttributes.ContentState) -> some View {
      Capsule()
        .fill(state.tintColor.opacity(0.2))
        .frame(height: 6)
        .overlay {
          GeometryReader { geometry in
            if state.isIncognitoSession {
              HStack {
                Spacer()
                Image(systemName: "eye.slash")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(state.tintColor)
                Spacer()
              }
            } else {
              HStack {
                Capsule()
                  .fill(state.tintColor)
                  .frame(width: geometry.size.width * state.progressFraction, height: 6)
                Spacer(minLength: 0)
              }
            }
          }
        }
        .animation(.easeInOut(duration: 0.25), value: state.progressFraction)
    }

    private func expandedTitleView(for state: ReaderActivityAttributes.ContentState) -> some View {
      VStack(spacing: 1) {
        if let seriesTitle = state.displaySeriesTitle {
          Text(seriesTitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Text(state.chapterTitle)
          .font(.caption)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .offset(y: -2)
    }
  }

  extension ReaderActivityAttributes.ContentState {
    fileprivate var displaySeriesTitle: String? {
      guard let seriesTitle, !seriesTitle.isEmpty else { return nil }
      return seriesTitle
    }

    fileprivate var isIncognitoSession: Bool {
      isIncognito
    }

    fileprivate var progressFraction: Double {
      min(max(readingProgress, 0), 1)
    }

    fileprivate var progressText: String {
      "\(Int((progressFraction * 100).rounded()))%"
    }

    fileprivate var tintColor: Color {
      isIncognitoSession ? .orange : .green
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
        chapterTitle: "#1058 - The Flame Emperor's Triumph",
        isIncognito: false,
        readingProgress: 0.58
      )
    }
  }

  #Preview("Reader Notification", as: .content, using: ReaderActivityAttributes.preview) {
    KMReaderReaderLiveActivity()
  } contentStates: {
    ReaderActivityAttributes.ContentState.readingPreview
  }
#endif
