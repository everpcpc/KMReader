//
// SeriesAlternateTitlesView.swift
//
//

import SwiftUI

struct SeriesAlternateTitlesView: View {
  let series: Series

  var body: some View {
    if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Alternate Titles")
          .font(.headline)
        VStack(alignment: .leading, spacing: 6) {
          ForEach(Array(alternateTitles.enumerated()), id: \.offset) { index, altTitle in
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
      }
    }
  }
}
