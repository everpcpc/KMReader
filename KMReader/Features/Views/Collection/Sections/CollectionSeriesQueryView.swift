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
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedSeriesIds: Set<String>
  let isAdmin: Bool
  let refreshSeries: () -> Void

  @Environment(\.modelContext) private var modelContext

  var body: some View {
    Group {
      if seriesViewModel.isLoading && seriesViewModel.browseSeriesIds.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(seriesViewModel.browseSeriesIds.enumerated()), id: \.element) { index, seriesId in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesSelectionItemView(
                    seriesId: seriesId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    selectedSeriesIds: $selectedSeriesIds,
                    onActionCompleted: refreshSeries
                  )
                } else {
                  SeriesQueryItemView(
                    seriesId: seriesId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .grid,
                    onActionCompleted: refreshSeries
                  )
                }
              }
              .onAppear {
                if index >= seriesViewModel.browseSeriesIds.count - 3 {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
          .padding(layoutHelper.spacing)
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(seriesViewModel.browseSeriesIds.enumerated()), id: \.element) { index, seriesId in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesSelectionItemView(
                    seriesId: seriesId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    selectedSeriesIds: $selectedSeriesIds,
                    onActionCompleted: refreshSeries
                  )
                } else {
                  SeriesQueryItemView(
                    seriesId: seriesId,
                    cardWidth: layoutHelper.cardWidth,
                    layout: .list,
                    onActionCompleted: refreshSeries
                  )
                }
              }
              .onAppear {
                if index >= seriesViewModel.browseSeriesIds.count - 3 {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
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
