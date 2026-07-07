//
// ReadingPagesHeatmapView.swift
//
//

import SwiftUI

struct ReadingPagesHeatmapView: View {
  let weeks: [ReadingPagesHeatmapWeek]
  @Binding var selectedPointId: String?

  private let tileSize: CGFloat = 13
  private let tileSpacing: CGFloat = 4

  private var maxValue: Double {
    weeks
      .flatMap(\.days)
      .compactMap { $0?.value }
      .max() ?? 0
  }

  private var selectedPoint: ReadingStatsTimePoint? {
    guard let selectedPointId else { return nil }
    return
      weeks
      .flatMap(\.days)
      .compactMap { $0 }
      .first { $0.id == selectedPointId }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: tileSpacing) {
          ForEach(weeks) { week in
            VStack(spacing: tileSpacing) {
              ForEach(0..<week.days.count, id: \.self) { index in
                if let point = week.days[index] {
                  Button {
                    selectedPointId = point.id
                  } label: {
                    RoundedRectangle(cornerRadius: 3)
                      .fill(tileColor(for: point.value))
                      .overlay {
                        if selectedPointId == point.id {
                          RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentColor, lineWidth: 2)
                        }
                      }
                      .frame(width: tileSize, height: tileSize)
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel(displayDate(for: point))
                  .accessibilityValue(formatPageCount(point.value))
                  #if os(macOS)
                    .help(
                      "\(displayDate(for: point))\n\(formatPageCount(point.value))"
                    )
                  #endif
                } else {
                  Color.clear
                    .frame(width: tileSize, height: tileSize)
                    .accessibilityHidden(true)
                }
              }
            }
          }
        }
        .padding(.vertical, 4)
      }

      HStack(spacing: 4) {
        ForEach(0..<5, id: \.self) { level in
          RoundedRectangle(cornerRadius: 3)
            .fill(legendColor(level: level))
            .frame(width: tileSize, height: tileSize)
        }
      }
      .accessibilityLabel(String(localized: "Pages Read"))

      if let selectedPoint {
        HStack(spacing: 8) {
          Text(displayDate(for: selectedPoint))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

          Spacer()

          Text(formatPageCount(selectedPoint.value))
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
        }
      }
    }
  }

  private func tileColor(for value: Double) -> Color {
    guard value > 0, maxValue > 0 else {
      return Color.secondary.opacity(0.12)
    }

    let normalized = min(max(value / maxValue, 0), 1)
    switch normalized {
    case ..<0.25:
      return Color.accentColor.opacity(0.28)
    case ..<0.5:
      return Color.accentColor.opacity(0.46)
    case ..<0.75:
      return Color.accentColor.opacity(0.68)
    default:
      return Color.accentColor.opacity(0.92)
    }
  }

  private func legendColor(level: Int) -> Color {
    switch level {
    case 0:
      return Color.secondary.opacity(0.12)
    case 1:
      return Color.accentColor.opacity(0.28)
    case 2:
      return Color.accentColor.opacity(0.46)
    case 3:
      return Color.accentColor.opacity(0.68)
    default:
      return Color.accentColor.opacity(0.92)
    }
  }

  private func displayDate(for point: ReadingStatsTimePoint) -> String {
    guard let date = ReadingStatsViewModel.parseDate(point.dateString) else {
      return point.name
    }
    return date.formattedMediumDate
  }

  private func formatPageCount(_ pages: Double) -> String {
    Int(max(pages.rounded(), 0)).formatted()
  }
}
