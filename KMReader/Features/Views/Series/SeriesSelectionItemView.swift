//
//  SeriesSelectionItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// View for series selection mode that accepts only seriesId and uses @Query to fetch the series.
struct SeriesSelectionItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode
  @Binding var selectedSeriesIds: Set<String>

  @Query private var komgaSeriesList: [KomgaSeries]

  init(
    seriesId: String,
    layout: BrowseLayoutMode,
    selectedSeriesIds: Binding<Set<String>>
  ) {
    self.seriesId = seriesId
    self.layout = layout
    self._selectedSeriesIds = selectedSeriesIds

    let instanceId = AppConfig.current.instanceId
    let compositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
    _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
  }

  private var komgaSeries: KomgaSeries? {
    komgaSeriesList.first
  }

  private var isSelected: Bool {
    selectedSeriesIds.contains(seriesId)
  }

  var body: some View {
    if let series = komgaSeries {
      Group {
        switch layout {
        case .grid:
          SeriesCardView(
            komgaSeries: series
          )
          .focusPadding()
        case .list:
          SeriesRowView(
            komgaSeries: series
          )
        }
      }
      .allowsHitTesting(false)
      .scaleEffect(isSelected ? 0.96 : 1.0)
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.accentColor, lineWidth: 2)
        }
      }
      .contentShape(Rectangle())
      .highPriorityGesture(
        TapGesture().onEnded {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isSelected {
              selectedSeriesIds.remove(seriesId)
            } else {
              selectedSeriesIds.insert(seriesId)
            }
          }
        }
      )
    }
  }
}
