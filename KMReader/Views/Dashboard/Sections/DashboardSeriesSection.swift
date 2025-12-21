//
//  DashboardSeriesSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DashboardSeriesSection: View {
  let section: DashboardSection
  var seriesViewModel: SeriesViewModel
  let refreshTrigger: UUID
  var onSeriesUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  @State private var seriesIds: [String] = []
  @State private var browseSeries: [KomgaSeries] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(section.displayName)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(Array(browseSeries.enumerated()), id: \.element.id) { index, series in
            DashboardSeriesItemView()
              .environment(series)
              .onAppear {
                if index >= browseSeries.count - 3 {
                  Task {
                    await loadMore()
                  }
                }
              }
          }
        }
        .padding()
      }
      .scrollClipDisabled()
    }
    .opacity(browseSeries.isEmpty ? 0 : 1)
    .frame(height: browseSeries.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) {
      Task {
        await refresh()
      }
    }
    .task {
      await loadInitial()
    }
  }

  private func loadInitial() async {
    guard !hasLoadedInitial else { return }
    await refresh()
  }

  private func refresh() async {
    currentPage = 0
    hasMore = true
    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    let libraryIds = dashboard.libraryIds
    let isFirstPage = currentPage == 0

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids: [String]
      switch section {
      case .recentlyAddedSeries:
        ids = KomgaSeriesStore.shared.fetchNewlyAddedSeriesIds(
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      case .recentlyUpdatedSeries:
        ids = KomgaSeriesStore.shared.fetchRecentlyUpdatedSeriesIds(
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      default:
        ids = []
      }
      updateState(ids: ids, moreAvailable: ids.count == pageSize, isFirstPage: isFirstPage)
    } else {
      // Online: fetch from API and sync
      do {
        let page: Page<Series>

        switch section {
        case .recentlyAddedSeries:
          page = try await SyncService.shared.syncNewSeries(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        case .recentlyUpdatedSeries:
          page = try await SyncService.shared.syncUpdatedSeries(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        default:
          withAnimation {
            isLoading = false
          }
          return
        }

        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last, isFirstPage: isFirstPage)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  private func updateState(ids: [String], moreAvailable: Bool, isFirstPage: Bool) {
    let series = KomgaSeriesStore.shared.fetchSeriesByIds(
      ids: ids, instanceId: AppConfig.currentInstanceId)
    withAnimation {
      if isFirstPage {
        seriesIds = ids
        browseSeries = series
      } else {
        seriesIds.append(contentsOf: ids)
        browseSeries.append(contentsOf: series)
      }
    }
    hasMore = moreAvailable
    currentPage += 1
  }
}

private struct DashboardSeriesItemView: View {
  @Environment(KomgaSeries.self) private var series

  var body: some View {
    NavigationLink(value: NavDestination.seriesDetail(seriesId: series.seriesId)) {
      SeriesCardView(
        cardWidth: PlatformHelper.dashboardCardWidth
      )
    }
    .focusPadding()
    .adaptiveButtonStyle(.plain)
  }
}
