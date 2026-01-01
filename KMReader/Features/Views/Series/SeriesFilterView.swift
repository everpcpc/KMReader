//
//  SeriesFilterView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesFilterView: View {
  @Binding var browseOpts: SeriesBrowseOptions
  @Binding var showFilterSheet: Bool

  var sortString: String {
    return
      "\(browseOpts.sortField.displayName) \(browseOpts.sortDirection == .ascending ? "↑" : "↓")"
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .padding(.leading, 4)
          .foregroundColor(.secondary)

        FilterChip(
          label: sortString,
          systemImage: "arrow.up.arrow.down",
          openSheet: $showFilterSheet
        )

        if let readLabel = readStatusLabel() {
          FilterChip(
            label: readLabel,
            systemImage: "eye",
            variant: readLabel.contains("≠") ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

        if let statusLabel = seriesStatusLabel() {
          FilterChip(
            label: statusLabel.label,
            systemImage: "chart.bar",
            variant: statusLabel.variant,
            openSheet: $showFilterSheet
          )
        }

        if browseOpts.oneshotFilter.isActive,
          let label = browseOpts.oneshotFilter.displayLabel(using: { _ in FilterStrings.oneshot })
        {
          FilterChip(
            label: label,
            systemImage: "dot.circle",
            variant: browseOpts.oneshotFilter.state == .exclude ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

        if browseOpts.deletedFilter.isActive,
          let label = browseOpts.deletedFilter.displayLabel(using: { _ in FilterStrings.deleted })
        {
          FilterChip(
            label: label,
            systemImage: "trash",
            variant: browseOpts.deletedFilter.state == .exclude ? .negative : .normal,
            openSheet: $showFilterSheet
          )
        }

      }
      .padding(4)
    }
    .scrollClipDisabled()
    .sheet(isPresented: $showFilterSheet) {
      SeriesBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }
}

extension SeriesFilterView {
  fileprivate func readStatusLabel() -> String? {
    buildReadStatusLabel(
      include: browseOpts.includeReadStatuses,
      exclude: browseOpts.excludeReadStatuses
    )
  }

  fileprivate func seriesStatusLabel() -> (label: String, variant: FilterChipVariant)? {
    let includeNames = browseOpts.includeSeriesStatuses
      .map { $0.displayName }
      .sorted()
    let excludeNames = browseOpts.excludeSeriesStatuses
      .map { $0.displayName }
      .sorted()

    let logicSymbol = browseOpts.seriesStatusLogic == .all ? "∧" : "∨"

    var parts: [String] = []
    if !includeNames.isEmpty {
      parts.append(includeNames.joined(separator: " \(logicSymbol) "))
    }
    if !excludeNames.isEmpty {
      parts.append("≠ " + excludeNames.joined(separator: " \(logicSymbol) "))
    }

    guard !parts.isEmpty else { return nil }
    let variant: FilterChipVariant = includeNames.isEmpty ? .negative : .normal
    return (label: parts.joined(separator: ", "), variant: variant)
  }
}
