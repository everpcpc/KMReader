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

  @AppStorage("currentAccount") private var current: Current = .init()
  @FetchAll private var komgaSeriesList: [KomgaSeriesRecord]
  @FetchAll private var seriesLocalStateList: [KomgaSeriesLocalStateRecord]

  init(
    seriesId: String,
    layout: BrowseLayoutMode
  ) {
    self.seriesId = seriesId
    self.layout = layout

    let instanceId = AppConfig.current.instanceId
    _komgaSeriesList = FetchAll(
      KomgaSeriesRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
    )
    _seriesLocalStateList = FetchAll(
      KomgaSeriesLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
    )
  }

  private var komgaSeries: KomgaSeries? {
    guard let record = komgaSeriesList.first else { return nil }
    return record.toKomgaSeries(localState: seriesLocalStateList.first)
  }

  var body: some View {
    if let series = komgaSeries {
      switch layout {
      case .grid:
        SeriesCardView(
          komgaSeries: series
        )
      case .list:
        SeriesRowView(
          komgaSeries: series
        )
      }
    } else {
      CardPlaceholder(layout: layout, kind: .series)
    }
  }
}
