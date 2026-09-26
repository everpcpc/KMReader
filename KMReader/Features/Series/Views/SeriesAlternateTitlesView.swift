//
// SeriesAlternateTitlesView.swift
//
//

import SwiftUI

struct SeriesAlternateTitlesView: View {
  let series: Series

  @State private var isExpanded = false

  private let collapsedLimit = 2

  private var alternateTitles: [AlternateTitle] {
    series.metadata.alternateTitles ?? []
  }

  private var displayedTitles: [AlternateTitle] {
    if isExpanded || alternateTitles.count <= collapsedLimit {
      return alternateTitles
    }
    return Array(alternateTitles.prefix(collapsedLimit))
  }

  var body: some View {
    if !alternateTitles.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Alternate Titles")
          .font(.headline)
        VStack(alignment: .leading, spacing: 6) {
          ForEach(Array(displayedTitles.enumerated()), id: \.offset) { index, altTitle in
            HStack(alignment: .top, spacing: 4) {
              Text("\(altTitle.label):")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
              Text(altTitle.title)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelectionIfAvailable()
            }
          }
        }
        if alternateTitles.count > collapsedLimit {
          ExpandToggleButton(isExpanded: $isExpanded)
        }
      }
    }
  }
}
