//
//  DashboardSeriesSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardSeriesSection: View {
  let section: DashboardSection
  var seriesViewModel: SeriesViewModel
  let refreshTrigger: UUID
  var onSeriesUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme

  @State private var seriesIds: [String] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  var backgroundColors: [Color] {
    if colorScheme == .dark {
      return [
        Color.white.opacity(0.2),
        Color.clear,
        Color.clear,
      ]
    } else {
      return [
        Color.clear,
        Color.clear,
        Color.secondary.opacity(0.1),
      ]
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(section.displayName)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 16) {
          ForEach(Array(seriesIds.enumerated()), id: \.element) { index, seriesId in
            SeriesQueryItemView(
              seriesId: seriesId,
              cardWidth: CGFloat(dashboardCardWidth),
              layout: .grid,
              onActionCompleted: onSeriesUpdated
            )
            .onAppear {
              if index >= seriesIds.count - 3 {
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
    .padding(.vertical, 12)
    .background {
      LinearGradient(
        colors: backgroundColors,
        startPoint: .top,
        endPoint: .bottom
      )
    }
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
    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    let libraryIds = dashboard.libraryIds
    let isFirstPage = currentPage == 0

    if AppConfig.isOffline {
      let ids: [String]
      switch section {
      case .recentlyAddedSeries:
        ids = KomgaSeriesStore.fetchNewlyAddedSeriesIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      case .recentlyUpdatedSeries:
        ids = KomgaSeriesStore.fetchRecentlyUpdatedSeriesIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      default:
        ids = []
      }
      updateState(ids: ids, moreAvailable: ids.count == pageSize, isFirstPage: isFirstPage)
    } else {
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
    withAnimation {
      if isFirstPage {
        seriesIds = ids
      } else {
        seriesIds.append(contentsOf: ids)
      }
    }
    hasMore = moreAvailable
    currentPage += 1
  }
}
