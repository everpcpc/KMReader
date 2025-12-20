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

  @State private var series: [Series] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var lastTriggeredIndex: Int = -1
  @State private var hasLoadedInitial = false

  // Load data when view appears (if not already loaded or if empty due to cancelled request)
  var shouldInitialLoad: Bool {
    return !hasLoadedInitial || (series.isEmpty && !isLoading)
  }

  // Loading indicator at the end - only show when loading more and has content
  var shouldShowLoadingIndicator: Bool {
    return isLoading && hasLoadedInitial && !series.isEmpty
  }

  func shouldLoadMore(index: Int) -> Bool {
    return index >= series.count - 3 && hasMore && !isLoading && lastTriggeredIndex != index
  }

  var body: some View {
    Group {
      if !series.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text(section.displayName)
            .font(.title3)
            .fontWeight(.bold)
            .padding(.horizontal)

          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
              ForEach(Array(series.enumerated()), id: \.element.id) { index, s in
                NavigationLink(value: NavDestination.seriesDetail(seriesId: s.id)) {
                  SeriesCardView(
                    series: s,
                    cardWidth: PlatformHelper.dashboardCardWidth,
                    onActionCompleted: onSeriesUpdated
                  )
                }
                .focusPadding()
                .adaptiveButtonStyle(.plain)
                .onAppear {
                  // Trigger load when we're near the last item (within last 3 items)
                  // Only trigger once per index to avoid repeated loads
                  if shouldLoadMore(index: index) {
                    lastTriggeredIndex = index
                    Task {
                      await loadMore()
                    }
                  }
                }
              }

              if shouldShowLoadingIndicator {
                ProgressView()
                  .frame(width: PlatformHelper.dashboardCardWidth, height: 200)
                  .padding(.trailing, 12)
              }
            }
            .padding()
          }
          .scrollClipDisabled()
          #if os(tvOS)
            .focusSection()
          #endif
        }
        .padding(.bottom, 16)
      } else {
        Color.clear
          .frame(height: 0)
      }
    }
    .onChange(of: refreshTrigger) {
      Task {
        await loadInitial()
      }
    }
    .onAppear {
      if shouldInitialLoad {
        Task {
          await loadInitial()
        }
      }
    }
  }

  private func loadInitial() async {
    currentPage = 0
    hasMore = true
    lastTriggeredIndex = -1
    hasLoadedInitial = false

    // Load first page first, then replace
    await loadMore(reset: true)
    hasLoadedInitial = true
  }

  private func loadMore(reset: Bool = false) async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    do {
      let libraryIds = dashboard.libraryIds
      let page: Page<Series>

      switch section {
      case .recentlyAddedSeries:
        page = try await SyncService.shared.syncNewSeries(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      case .recentlyUpdatedSeries:
        page = try await SyncService.shared.syncUpdatedSeries(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      default:
        isLoading = false
        return
      }

      withAnimation {
        if reset {
          series = page.content
        } else {
          series.append(contentsOf: page.content)
        }
      }

      hasMore = !page.last
      currentPage += 1

      // Reset trigger index after loading to allow next trigger
      lastTriggeredIndex = -1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }
}
