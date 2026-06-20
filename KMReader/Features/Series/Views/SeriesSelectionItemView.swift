//
// SeriesSelectionItemView.swift
//
//

import SwiftUI

/// View for series selection mode that accepts only seriesId and fetches a series display projection.
struct SeriesSelectionItemView: View {
  let seriesId: String
  let layout: BrowseLayoutMode
  @Binding var selectedSeriesIds: Set<String>

  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var item: SeriesDisplayItem?

  init(
    seriesId: String,
    layout: BrowseLayoutMode,
    selectedSeriesIds: Binding<Set<String>>
  ) {
    self.seriesId = seriesId
    self.layout = layout
    self._selectedSeriesIds = selectedSeriesIds

  }

  private var isSelected: Bool {
    selectedSeriesIds.contains(seriesId)
  }

  var body: some View {
    Group {
      if let item {
        Group {
          switch layout {
          case .grid:
            SeriesCardView(
              item: item
            )
          case .list:
            SeriesRowView(
              item: item
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
        .animation(.default, value: isSelected)
        .contentShape(Rectangle())
        .highPriorityGesture(
          TapGesture().onEnded {
            if isSelected {
              selectedSeriesIds.remove(seriesId)
            } else {
              selectedSeriesIds.insert(seriesId)
            }
          }
        )
      }
    }
    .task(id: "\(current.instanceId)|\(seriesId)") {
      await loadItem()
    }
  }

  private func loadItem() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchSeriesDisplayItem(
      seriesId: seriesId,
      instanceId: current.instanceId
    )
  }
}
