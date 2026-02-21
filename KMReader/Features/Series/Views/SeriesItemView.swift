//
// SeriesItemView.swift
//
//

import SwiftUI

struct SeriesItemView: View {
  let series: Series
  let localState: KomgaSeriesLocalStateRecord?
  let layout: BrowseLayoutMode

  var body: some View {
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
  }
}
