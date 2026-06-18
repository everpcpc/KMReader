//
// SeriesReadingActionBar.swift
//
//

import SwiftUI

struct SeriesReadingActionBar: View {
  let actionTitle: String
  let book: Book?
  let fallbackTitle: String
  let isResuming: Bool
  let isResolving: Bool
  let action: () -> Void

  @ScaledMetric(relativeTo: .callout) private var iconSize = 36.0

  private var displayTitle: String {
    guard let book else {
      return isResolving ? String(localized: "Loading...") : fallbackTitle
    }
    if book.oneshot || book.metadata.number.isEmpty {
      return book.metadata.title
    }
    return "#\(book.metadata.number) - \(book.metadata.title)"
  }

  private var actionSummary: String {
    guard let progressSummary else { return actionTitle }
    return "\(actionTitle) · \(progressSummary)"
  }

  private var actionIcon: String {
    isResuming ? "forward.fill" : "play.fill"
  }

  private var progressSummary: String? {
    guard let book, let progress = book.readProgress, !progress.completed else { return nil }
    let page = progress.page
    guard book.media.pagesCount > 0 else { return "Page \(page)" }
    let value = min(max(Double(page) / Double(book.media.pagesCount), 0), 1)
    return "Page \(page) · \(value.formatted(.percent.precision(.fractionLength(0))))"
  }

  var body: some View {
    Button(action: action) {
      styledContent
        .contentShape(Capsule(style: .continuous))
    }
    .adaptiveButtonStyle(.plain)
  }

  @ViewBuilder
  private var styledContent: some View {
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      content
        .glassEffect(
          .regular.interactive(),
          in: Capsule(style: .continuous)
        )
    } else {
      content
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay {
          Capsule(style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 7)
    }
  }

  private var content: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(actionSummary)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Text(displayTitle)
          .font(.callout.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      if isResolving {
        ProgressView()
          .controlSize(.small)
      }

      HStack(spacing: 12) {
        Image(systemName: actionIcon)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(Color.accentColor)
          .frame(width: iconSize, height: iconSize)
          .background(Color.primary.opacity(0.08), in: Circle())
          .overlay {
            Circle()
              .strokeBorder(Color.primary.opacity(0.06))
          }
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 10)
    .padding(.vertical, 9)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
