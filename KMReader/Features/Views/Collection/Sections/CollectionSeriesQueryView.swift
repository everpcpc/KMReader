//
//  CollectionSeriesQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionSeriesQueryView: View {
  let collectionId: String
  @Bindable var seriesViewModel: SeriesViewModel
  let browseOpts: CollectionSeriesBrowseOptions
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedSeriesIds: Set<String>
  let isAdmin: Bool
  let refreshSeries: () -> Void

  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @Environment(\.modelContext) private var modelContext

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  var body: some View {
    Group {
      if seriesViewModel.isLoading && seriesViewModel.pagination.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: LayoutConfig.spacing) {
            ForEach(seriesViewModel.pagination.items) { series in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesSelectionItemView(
                    seriesId: series.id,
                    layout: .grid,
                    selectedSeriesIds: $selectedSeriesIds,
                    onActionCompleted: refreshSeries
                  )
                } else {
                  SeriesQueryItemView(
                    seriesId: series.id,
                    layout: .grid,
                    onActionCompleted: refreshSeries
                  )
                }
              }
              .padding(.bottom)
              .onAppear {
                if seriesViewModel.pagination.shouldLoadMore(after: series) {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
          .padding(.horizontal, LayoutConfig.spacing)
        case .list:
          LazyVStack {
            ForEach(seriesViewModel.pagination.items) { series in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesSelectionItemView(
                    seriesId: series.id,
                    layout: .list,
                    selectedSeriesIds: $selectedSeriesIds,
                    onActionCompleted: refreshSeries
                  )
                } else {
                  SeriesQueryItemView(
                    seriesId: series.id,
                    layout: .list,
                    onActionCompleted: refreshSeries
                  )
                }
              }
              .onAppear {
                if seriesViewModel.pagination.shouldLoadMore(after: series) {
                  Task { await loadMore(refresh: false) }
                }
              }
              if !seriesViewModel.pagination.isLast(series) {
                Divider()
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
  }

  private func loadMore(refresh: Bool) async {
    await seriesViewModel.loadCollectionSeries(
      context: modelContext,
      collectionId: collectionId,
      browseOpts: browseOpts,
      refresh: refresh
    )
  }
}
