//
// SeriesSelectionItemView.swift
//
//

import SQLiteData
import SwiftUI

/// View for series selection mode that accepts only seriesId and reads the local record.
struct SeriesSelectionItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode
  @Binding var selectedSeriesIds: Set<String>

  @FetchAll private var seriesRecords: [KomgaSeriesRecord]
  @FetchAll private var seriesLocalStateList: [KomgaSeriesLocalStateRecord]

  init(
    seriesId: String,
    layout: BrowseLayoutMode,
    selectedSeriesIds: Binding<Set<String>>
  ) {
    self.seriesId = seriesId
    self.layout = layout
    self._selectedSeriesIds = selectedSeriesIds

    let instanceId = AppConfig.current.instanceId
    _seriesRecords = FetchAll(
      KomgaSeriesRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
    )
    _seriesLocalStateList = FetchAll(
      KomgaSeriesLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.seriesId.eq(seriesId) }
    )
  }

  private var series: Series? {
    seriesRecords.first?.toSeries()
  }

  private var localState: KomgaSeriesLocalStateRecord? {
    seriesLocalStateList.first
  }

  private var isSelected: Bool {
    selectedSeriesIds.contains(seriesId)
  }

  var body: some View {
    if let series = series {
      Group {
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
