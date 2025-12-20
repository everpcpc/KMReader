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
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  var body: some View {
    DashboardSeriesListView(
      seriesIds: seriesIds,
      instanceId: AppConfig.currentInstanceId,
      section: section,
      seriesViewModel: seriesViewModel,
      loadMore: {
        Task {
          await loadMore()
        }
      }
    )
    .opacity(seriesIds.isEmpty ? 0 : 1)
    .frame(height: seriesIds.isEmpty ? 0 : nil)
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
    withAnimation {
      seriesIds = []
    }

    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    withAnimation {
      isLoading = true
    }

    let libraryIds = dashboard.libraryIds

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = KomgaSeriesStore.shared.fetchRecentSeriesIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      withAnimation {
        seriesIds.append(contentsOf: ids)
      }
      hasMore = ids.count == pageSize
      currentPage += 1
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

        withAnimation {
          seriesIds.append(contentsOf: page.content.map { $0.id })
        }
        hasMore = !page.last
        currentPage += 1
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }
}
