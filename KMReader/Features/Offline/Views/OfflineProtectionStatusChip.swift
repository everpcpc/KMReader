//
// OfflineProtectionStatusChip.swift
//
//

import SwiftUI

struct OfflineProtectionStatusChip: View {
  let label: String
  let systemImage: String
  let backgroundColor: Color
  let foregroundColor: Color
  let sources: [OfflineProtectionSource]

  var body: some View {
    if sources.isEmpty {
      InfoChip(
        label: label,
        systemImage: systemImage,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor
      )
    } else {
      Menu {
        ForEach(sources) { source in
          NavigationLink(value: destination(for: source)) {
            Label(source.displayName, systemImage: source.kind.systemImage)
          }
        }
      } label: {
        HStack(spacing: 5) {
          Image(systemName: systemImage)
            .font(.caption2)
          Text(label)
            .font(.caption)
            .lineLimit(1)
          Image(systemName: "lock.fill")
            .font(.caption)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(backgroundColor, in: Capsule())
        .overlay {
          Capsule()
            .stroke(foregroundColor.opacity(0.3), lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
    }
  }

  private func destination(for source: OfflineProtectionSource) -> NavDestination {
    switch source.kind {
    case .series:
      return .seriesDetail(seriesId: source.sourceId)
    case .readList:
      return .readListDetail(readListId: source.sourceId)
    }
  }
}
