//
//  DashboardSectionView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardSectionView: View {
  let section: DashboardSection
  let refreshTrigger: UUID
  var onUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var itemIds: [String] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  private var backgroundColors: [Color] {
    if colorScheme == .dark {
      return [
        Color.white.opacity(0.2),
        Color.clear,
      ]
    } else {
      return [
        Color.clear,
        Color.secondary.opacity(0.1),
      ]
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      NavigationLink(value: NavDestination.dashboardSectionDetail(section: section)) {
        HStack {
          Text(section.displayName)
            .font(.appSerifDesign(size: 22, weight: .bold))
          Image(systemName: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 16) {
          ForEach(itemIds, id: \.self) { itemId in
            itemView(for: itemId)
              .onAppear {
                // O(1): suffix is a slice, contains checks only 3 elements
                if itemIds.suffix(3).contains(itemId) {
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
    .padding(.vertical, 16)
    .background {
      LinearGradient(
        colors: backgroundColors,
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .opacity(itemIds.isEmpty ? 0 : 1)
    .frame(height: itemIds.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) {
      Task {
        await refresh()
      }
    }
    .task {
      await loadInitial()
    }
  }

  @ViewBuilder
  private func itemView(for itemId: String) -> some View {
    if section.isBookSection {
      BookQueryItemView(
        bookId: itemId,
        cardWidth: CGFloat(dashboardCardWidth),
        layout: .grid,
        onBookUpdated: onUpdated,
        showSeriesTitle: true
      )
    } else {
      SeriesQueryItemView(
        seriesId: itemId,
        cardWidth: CGFloat(dashboardCardWidth),
        layout: .grid,
        onActionCompleted: onUpdated
      )
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
      if section.isBookSection {
        ids = section.fetchOfflineBookIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      } else {
        ids = section.fetchOfflineSeriesIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: currentPage * pageSize,
          limit: pageSize
        )
      }
      updateState(ids: ids, moreAvailable: ids.count == pageSize, isFirstPage: isFirstPage)
    } else {
      do {
        if section.isBookSection {
          if let page = try await section.fetchBooks(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          ) {
            let ids = page.content.map { $0.id }
            updateState(ids: ids, moreAvailable: !page.last, isFirstPage: isFirstPage)
          }
        } else {
          if let page = try await section.fetchSeries(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          ) {
            let ids = page.content.map { $0.id }
            updateState(ids: ids, moreAvailable: !page.last, isFirstPage: isFirstPage)
          }
        }
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
        itemIds = ids
      } else {
        itemIds.append(contentsOf: ids)
      }
    }
    hasMore = moreAvailable
    currentPage += 1
  }
}
