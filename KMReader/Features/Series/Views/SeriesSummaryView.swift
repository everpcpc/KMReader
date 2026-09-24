//
// SeriesSummaryView.swift
//
//

import SwiftUI

/// Series summary, falling back to the aggregated books metadata summary when
/// the series itself has none.
struct SeriesSummaryView: View {
  let series: Series

  var body: some View {
    if let summary = series.metadata.summary, !summary.isEmpty {
      ExpandableSummaryView(
        summary: summary,
        titleIcon: nil,
        subtitle: nil,
        titleStyle: .headline
      )
    } else if let summary = series.booksMetadata.summary, !summary.isEmpty {
      let subtitle = series.booksMetadata.summaryNumber.map { "(from Book #\($0))" }
      ExpandableSummaryView(
        summary: summary,
        titleIcon: nil,
        subtitle: subtitle,
        titleStyle: .headline
      )
    }
  }
}
