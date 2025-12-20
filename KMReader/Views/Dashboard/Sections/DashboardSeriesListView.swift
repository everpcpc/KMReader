//
//  DashboardSeriesListView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardSeriesListView: View {
  let seriesIds: [String]
  let instanceId: String
  let section: DashboardSection
  let seriesViewModel: SeriesViewModel
  var loadMore: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(section.displayName)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(Array(seriesIds.enumerated()), id: \.element) { index, seriesId in
            DashboardSeriesItemView(
              seriesId: seriesId,
              instanceId: instanceId
            )
            .onAppear {
              if index >= seriesIds.count - 3 {
                loadMore?()
              }
            }
          }
        }
        .padding()
      }
      .scrollClipDisabled()
    }
    .padding(.bottom, 16)
  }
}

private struct DashboardSeriesItemView: View {
  let seriesId: String
  let instanceId: String

  @Query private var series: [KomgaSeries]

  init(seriesId: String, instanceId: String) {
    self.seriesId = seriesId
    self.instanceId = instanceId
    let compositeId = "\(instanceId)_\(seriesId)"
    _series = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
  }

  var body: some View {
    if let komgaSeries = series.first {
      NavigationLink(value: NavDestination.seriesDetail(seriesId: komgaSeries.seriesId)) {
        SeriesCardView(
          cardWidth: PlatformHelper.dashboardCardWidth
        )
        .environment(komgaSeries)
      }
      .focusPadding()
      .adaptiveButtonStyle(.plain)
    }
  }
}
