//
// SeriesQueryItemView.swift
//
//

import SQLiteData
import SwiftUI

/// Wrapper view that accepts only seriesId and fetches the local record reactively.
struct SeriesQueryItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode

  @FetchAll private var seriesRecords: [KomgaSeriesRecord]
  @FetchAll private var seriesLocalStateList: [KomgaSeriesLocalStateRecord]

  init(
    seriesId: String,
    layout: BrowseLayoutMode
  ) {
    self.seriesId = seriesId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _seriesRecords = FetchAll(
      KomgaSeriesRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }.limit(1)
    )
    _seriesLocalStateList = FetchAll(
      KomgaSeriesLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }.limit(1)
    )
  }

  private var series: Series? {
    seriesRecords.first?.toSeries()
  }

  private var localState: KomgaSeriesLocalStateRecord? {
    seriesLocalStateList.first
  }

  var body: some View {
    if let series = series {
      switch layout {
      case .grid:
        SeriesCardView(
          series: series,
          localState: localState
        )
      case .list:
        SeriesRowView(
          series: series,
          localState: localState
        )
      }
    } else {
      CardPlaceholder(layout: layout, kind: .series)
    }
  }
}
