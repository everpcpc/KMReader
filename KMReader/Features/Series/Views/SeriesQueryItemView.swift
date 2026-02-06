//
//  SeriesQueryItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// Wrapper view that accepts only seriesId and uses @Query to fetch the series reactively.
struct SeriesQueryItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode
  let prefetchedSeries: KomgaSeries?

  @AppStorage("currentAccount") private var current: Current = .init()
  @Query private var komgaSeriesList: [KomgaSeries]

  init(
    seriesId: String,
    layout: BrowseLayoutMode,
    komgaSeries: KomgaSeries? = nil
  ) {
    self.seriesId = seriesId
    self.layout = layout
    self.prefetchedSeries = komgaSeries

    if komgaSeries == nil {
      let compositeId = CompositeID.generate(id: seriesId)
      _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
    } else {
      _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { _ in false })
    }
  }

  private var komgaSeries: KomgaSeries? {
    prefetchedSeries ?? komgaSeriesList.first
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
