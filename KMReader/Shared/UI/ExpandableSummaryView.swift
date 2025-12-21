//
//  ExpandableSummaryView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ExpandableSummaryView: View {
  let summary: String
  let title: String
  let titleIcon: String?
  let subtitle: String?
  let titleStyle: TitleStyle

  enum TitleStyle {
    case caption
    case headline
  }

  @State private var isExpanded = false
  @State private var fullTextHeight: CGFloat = 0
  @State private var collapsedTextHeight: CGFloat = 0

  private let collapsedLineLimit = 3
  private let heightTolerance: CGFloat = 1.0

  private var needsExpansion: Bool {
    let heightDifference = fullTextHeight - collapsedTextHeight
    return heightDifference > heightTolerance && collapsedTextHeight > 0 && fullTextHeight > 0
  }

  init(
    summary: String,
    title: String = String(localized: "Summary"),
    titleIcon: String? = "text.alignleft",
    subtitle: String? = nil,
    titleStyle: TitleStyle = .caption
  ) {
    self.summary = summary
    self.title = title
    self.titleIcon = titleIcon
    self.subtitle = subtitle
    self.titleStyle = titleStyle
  }

  private var titleView: some View {
    Group {
      switch titleStyle {
      case .caption:
        HStack(spacing: 4) {
          if let titleIcon = titleIcon {
            Image(systemName: titleIcon)
              .font(.caption)
          }
          Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
          if let subtitle = subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .foregroundColor(.secondary)
      case .headline:
        HStack {
          Text(title)
            .font(.headline)
          if let subtitle = subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      titleView

      Text(summary)
        .font(.body)
        .foregroundColor(.primary)
        .lineLimit(isExpanded ? nil : collapsedLineLimit)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .background(
          GeometryReader { geometry in
            VStack(spacing: 0) {
              Text(summary)
                .font(.body)
                .lineLimit(collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: geometry.size.width, alignment: .leading)
                .background(
                  GeometryReader { textGeometry in
                    Color.clear
                      .preference(
                        key: TextHeightPreferenceKey.self,
                        value: textGeometry.size.height
                      )
                  }
                )

              Text(summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: geometry.size.width, alignment: .leading)
                .background(
                  GeometryReader { textGeometry in
                    Color.clear
                      .preference(
                        key: FullTextHeightPreferenceKey.self,
                        value: textGeometry.size.height
                      )
                  }
                )
            }
            .opacity(0)
            .frame(width: geometry.size.width, alignment: .topLeading)
          }
        )

      if needsExpansion {
        Button {
          withAnimation {
            isExpanded.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption2)
            Text(isExpanded ? "Show Less" : "Show More")
              .font(.caption)
          }
        }
      }
    }
    .onPreferenceChange(TextHeightPreferenceKey.self) { height in
      if height > 0 {
        collapsedTextHeight = height
      }
    }
    .onPreferenceChange(FullTextHeightPreferenceKey.self) { height in
      if height > 0 {
        fullTextHeight = height
      }
    }
  }
}

private struct TextHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct FullTextHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
