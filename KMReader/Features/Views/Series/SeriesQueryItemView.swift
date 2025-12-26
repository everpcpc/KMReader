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
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  var onActionCompleted: (() -> Void)? = nil

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Query private var komgaSeriesList: [KomgaSeries]

  init(
    seriesId: String,
    cardWidth: CGFloat,
    layout: BrowseLayoutMode,
    onActionCompleted: (() -> Void)? = nil
  ) {
    self.seriesId = seriesId
    self.cardWidth = cardWidth
    self.layout = layout
    self.onActionCompleted = onActionCompleted

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(seriesId)"
    _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
  }

  private var komgaSeries: KomgaSeries? {
    komgaSeriesList.first
  }

  var body: some View {
    if let series = komgaSeries {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: series.seriesId)) {
        switch layout {
        case .grid:
          SeriesCardView(
            komgaSeries: series,
            cardWidth: cardWidth,
            onActionCompleted: onActionCompleted
          )
        case .list:
          SeriesRowView(
            komgaSeries: series,
            onActionCompleted: onActionCompleted
          )
        }
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)
    }
  }
}
