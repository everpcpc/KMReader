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
  let seriesIds: [String]
  let seriesViewModel: SeriesViewModel
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedSeriesIds: Set<String>
  let isAdmin: Bool
  let onActionCompleted: () -> Void
  let loadMore: (Bool) async -> Void

  @Query private var series: [KomgaSeries]

  init(
    collectionId: String,
    seriesIds: [String],
    seriesViewModel: SeriesViewModel,
    layoutHelper: BrowseLayoutHelper,
    browseLayout: BrowseLayoutMode,
    isSelectionMode: Bool,
    selectedSeriesIds: Binding<Set<String>>,
    isAdmin: Bool,
    onActionCompleted: @escaping () -> Void,
    loadMore: @escaping (Bool) async -> Void
  ) {
    self.collectionId = collectionId
    self.seriesIds = seriesIds
    self.seriesViewModel = seriesViewModel
    self.layoutHelper = layoutHelper
    self.browseLayout = browseLayout
    self.isSelectionMode = isSelectionMode
    self._selectedSeriesIds = selectedSeriesIds
    self.isAdmin = isAdmin
    self.onActionCompleted = onActionCompleted
    self.loadMore = loadMore

    let instanceId = AppConfig.currentInstanceId
    let predicate = #Predicate<KomgaSeries> { series in
      series.instanceId == instanceId && seriesIds.contains(series.seriesId)
    }

    // Sorting collection series is usually by the order in seriesIds or name
    // Since we can't easily sort by index in seriesIds array in Predicate, we'll sort by name or just fetch all
    _series = Query(filter: predicate, sort: [SortDescriptor(\.name, order: .forward)])
  }

  var body: some View {
    Group {
      if seriesViewModel.isLoading && series.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(series) { s in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesCardView(
                    cardWidth: layoutHelper.cardWidth,
                    onActionCompleted: onActionCompleted
                  )
                  .environment(s)
                  .focusPadding()
                  .allowsHitTesting(false)
                  .overlay(alignment: .topTrailing) {
                    Image(
                      systemName: selectedSeriesIds.contains(s.seriesId)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundColor(
                      selectedSeriesIds.contains(s.seriesId) ? .accentColor : .secondary
                    )
                    .font(.title3)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                  }
                  .contentShape(Rectangle())
                  .highPriorityGesture(
                    TapGesture().onEnded {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedSeriesIds.contains(s.seriesId) {
                          selectedSeriesIds.remove(s.seriesId)
                        } else {
                          selectedSeriesIds.insert(s.seriesId)
                        }
                      }
                    }
                  )
                } else {
                  NavigationLink(value: NavDestination.seriesDetail(seriesId: s.seriesId)) {
                    SeriesCardView(
                      cardWidth: layoutHelper.cardWidth,
                      onActionCompleted: onActionCompleted
                    )
                    .environment(s)
                  }
                  .focusPadding()
                  .adaptiveButtonStyle(.plain)
                }
              }
              .onAppear {
                if s.id == series.last?.id {
                  Task { await loadMore(false) }
                }
              }
            }
          }
          .padding(layoutHelper.spacing)
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(series) { s in
              Group {
                if isSelectionMode && isAdmin {
                  SeriesRowView(
                    onActionCompleted: onActionCompleted
                  )
                  .environment(s)
                  .allowsHitTesting(false)
                  .overlay(alignment: .trailing) {
                    Image(
                      systemName: selectedSeriesIds.contains(s.seriesId)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundColor(
                      selectedSeriesIds.contains(s.seriesId) ? .accentColor : .secondary
                    )
                    .font(.title3)
                    .padding(.trailing, 16)
                  }
                  .contentShape(Rectangle())
                  .highPriorityGesture(
                    TapGesture().onEnded {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedSeriesIds.contains(s.seriesId) {
                          selectedSeriesIds.remove(s.seriesId)
                        } else {
                          selectedSeriesIds.insert(s.seriesId)
                        }
                      }
                    }
                  )
                } else {
                  NavigationLink(value: NavDestination.seriesDetail(seriesId: s.seriesId)) {
                    SeriesRowView(
                      onActionCompleted: onActionCompleted
                    )
                    .environment(s)
                  }
                  .adaptiveButtonStyle(.plain)
                }
              }
              .onAppear {
                if s.id == series.last?.id {
                  Task { await loadMore(false) }
                }
              }
            }
          }
        }
      }
    }
  }
}
