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
            ForEach(seriesViewModel.browseSeriesIds, id: \.self) { seriesId in
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
              .padding(.bottom)
              .onAppear {
                if seriesViewModel.browseSeriesIds.suffix(3).contains(seriesId) {
                  Task { await loadMore(refresh: false) }
                }
              }
            }
          }
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(seriesViewModel.browseSeriesIds, id: \.self) { seriesId in
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
                if seriesViewModel.browseSeriesIds.suffix(3).contains(seriesId) {
                  Task { await loadMore(refresh: false) }
                }
              }
              if seriesId != seriesViewModel.browseSeriesIds.last {
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
