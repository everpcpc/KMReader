//
//  CollectionSeriesFilterView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionSeriesFilterView: View {
  @Binding var browseOpts: CollectionSeriesBrowseOptions
  @Binding var showFilterSheet: Bool
  @Binding var layoutMode: BrowseLayoutMode

  var emptyFilter: Bool {
    return browseOpts.includeReadStatuses.isEmpty
      && browseOpts.excludeReadStatuses.isEmpty
      && browseOpts.includeSeriesStatuses.isEmpty
      && browseOpts.excludeSeriesStatuses.isEmpty
      && !browseOpts.oneshotFilter.isActive
      && !browseOpts.deletedFilter.isActive
  }

  var body: some View {
    HStack(spacing: 8) {
      LayoutModePicker(selection: $layoutMode)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          Image(systemName: "line.3.horizontal.decrease.circle")
            .padding(.leading, 4)
            .foregroundColor(.secondary)

          FilterChip(
            label: String(localized: "Filter"),
            systemImage: "line.3.horizontal.decrease.circle",
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
    }
    .sheet(isPresented: $showFilterSheet) {
      CollectionSeriesBrowseOptionsSheet(browseOpts: $browseOpts)
    }
  }

  private func seriesStatusLabel() -> (label: String, variant: FilterChipVariant)? {
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

extension CollectionSeriesFilterView {
  fileprivate func readStatusLabel() -> String? {
    buildReadStatusLabel(
      include: browseOpts.includeReadStatuses,
      exclude: browseOpts.excludeReadStatuses
    )
  }
}
