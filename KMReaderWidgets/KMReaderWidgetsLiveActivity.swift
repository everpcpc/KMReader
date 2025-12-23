//
//  KMReaderWidgetsLiveActivity.swift
//  KMReaderWidgets
//
//  Created by Chuan Chuan on 2025/12/23.
//

import SwiftUI
import WidgetKit

#if os(iOS)
  import ActivityKit

  struct KMReaderWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
      ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
        // Lock screen/banner UI
        VStack(spacing: 8) {
          // Header with series info
          HStack {
            Image(systemName: "arrow.down.circle.fill")
              .font(.title2)
              .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
              Text(context.state.seriesTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

              Text(context.state.bookInfo)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            }

            Spacer()

            // Progress percentage
            Text("\(Int(context.state.progress * 100))%")
              .font(.title3.weight(.bold))
              .foregroundStyle(.blue)
              .monospacedDigit()
          }

          // Progress bar
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))

              RoundedRectangle(cornerRadius: 4)
                .fill(
                  LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: geometry.size.width * context.state.progress)
            }
          }
          .frame(height: 6)

          // Footer stats
          HStack {
            if context.state.pendingCount > 0 {
              Label("\(context.state.pendingCount)", systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if context.state.failedCount > 0 {
              Label("\(context.state.failedCount)", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
            }
          }
          .padding(.horizontal)
        }
        .padding(12)
        .activityBackgroundTint(Color(.systemBackground).opacity(0.95))
        .activitySystemActionForegroundColor(.primary)

      } dynamicIsland: { context in
        DynamicIsland {
          // Expanded UI
          DynamicIslandExpandedRegion(.leading) {
            Image(systemName: "arrow.down.circle.fill")
              .foregroundStyle(.blue)
              .font(.title2)
          }
          DynamicIslandExpandedRegion(.trailing) {
            Text("\(Int(context.state.progress * 100))%")
              .font(.headline.weight(.bold))
              .foregroundStyle(.blue)
              .monospacedDigit()
          }
          DynamicIslandExpandedRegion(.center) {
            VStack(spacing: 2) {
              Text(context.state.seriesTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(context.state.bookInfo)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            }
          }
          DynamicIslandExpandedRegion(.bottom) {
            ProgressView(value: context.state.progress)
              .tint(.blue)
          }
        } compactLeading: {
          Image(systemName: "arrow.down.circle.fill")
            .foregroundStyle(.blue)
        } compactTrailing: {
          Text("\(Int(context.state.progress * 100))%")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.blue)
            .monospacedDigit()
        } minimal: {
          Image(systemName: "arrow.down.circle.fill")
            .foregroundStyle(.blue)
        }
        .keylineTint(.blue)
      }
    }
  }

  extension DownloadActivityAttributes {
    fileprivate static var preview: DownloadActivityAttributes {
      DownloadActivityAttributes(totalBooks: 5)
    }
  }

  extension DownloadActivityAttributes.ContentState {
    fileprivate static var downloading: DownloadActivityAttributes.ContentState {
      DownloadActivityAttributes.ContentState(
        seriesTitle: "One Piece",
        bookInfo: "#1058 - The Flame Emperor's Triumph",
        progress: 0.65,
        pendingCount: 12,
        failedCount: 1
      )
    }
  }

  #Preview("Notification", as: .content, using: DownloadActivityAttributes.preview) {
    KMReaderWidgetsLiveActivity()
  } contentStates: {
    DownloadActivityAttributes.ContentState.downloading
  }
#endif
