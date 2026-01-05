//
//  DashboardSectionView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

enum DashboardRefreshSource {
  case manual
  case auto
}

struct DashboardRefreshTrigger: Equatable {
  let id: UUID
  let source: DashboardRefreshSource
  var sectionsToRefresh: Set<DashboardSection>?  // nil means refresh all
}

@MainActor
struct DashboardSectionView: View {
  let section: DashboardSection
  let refreshTrigger: DashboardRefreshTrigger
  var onUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("dashboardSectionCache") private var sectionCache: DashboardSectionCache =
    DashboardSectionCache()
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 20)
  @State private var isLoading = false
  @State private var hasLoadedInitial = false
  @State private var didSeedFromCache = false
  @State private var isHoveringScrollArea = false

  private var backgroundColors: [Color] {
    if colorScheme == .dark {
      return [
        Color.secondary.opacity(0.2),
        Color.clear,
      ]
    } else {
      return [
        Color.clear,
        Color.secondary.opacity(0.1),
      ]
    }
  }

  private var cardWidth: CGFloat {
    LayoutConfig.cardWidth(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
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

      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(alignment: .top, spacing: spacing) {
            ForEach(pagination.items) { item in
              itemView(for: item.id)
                .id(item.id)
                .frame(width: cardWidth)
                .onAppear {
                  if pagination.shouldLoadMore(after: item) {
                    Task {
                      await loadMore()
                    }
                  }
                }
            }
          }
          .padding(.vertical)
        }
        .contentMargins(.horizontal, spacing, for: .scrollContent)
        .scrollClipDisabled()
        .overlay {
          HorizontalScrollButtons(
            scrollProxy: proxy,
            itemIds: pagination.items.map(\.id),
            isVisible: isHoveringScrollArea
          )
        }
      }
    }
    .padding(.vertical, 16)
    #if os(iOS) || os(macOS)
      .background {
        LinearGradient(
          colors: backgroundColors,
          startPoint: .top,
          endPoint: .bottom
        )
      }
    #endif
    #if os(macOS)
      .onContinuousHover { phase in
        switch phase {
        case .active:
          withAnimation {
            isHoveringScrollArea = true
          }
        case .ended:
          withAnimation {
            isHoveringScrollArea = false
          }
        }
      }
    #endif
    .opacity(pagination.isEmpty ? 0 : 1)
    .frame(height: pagination.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) {
      // Skip if targeted refresh excludes this section
      if let sections = refreshTrigger.sectionsToRefresh, !sections.contains(section) {
        return
      }
      if refreshTrigger.source == .auto, pagination.currentPage > 0 {
        return
      }
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
        layout: .grid,
        onBookUpdated: onUpdated,
        showSeriesTitle: true
      )
    } else {
      SeriesQueryItemView(
        seriesId: itemId,
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
    pagination.reset()
    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard pagination.hasMorePages, !isLoading else { return }
    isLoading = true

    let libraryIds = dashboard.libraryIds
    let isFirstPage = pagination.currentPage == 0

    if !AppConfig.isOffline {
      await seedFromCacheIfNeeded(
        isFirstPage: isFirstPage,
        libraryIds: libraryIds
      )
    }

    if AppConfig.isOffline {
      let ids: [String]
      if section.isBookSection {
        ids = section.fetchOfflineBookIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      } else {
        ids = section.fetchOfflineSeriesIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        if section.isBookSection {
          if let page = try await section.fetchBooks(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
            if isFirstPage {
              _ = sectionCache.updateIfChanged(section: section, ids: ids)
            }
            applyPage(ids: ids, moreAvailable: !page.last)
          }
        } else {
          if let page = try await section.fetchSeries(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
            if isFirstPage {
              _ = sectionCache.updateIfChanged(section: section, ids: ids)
            }
            applyPage(ids: ids, moreAvailable: !page.last)
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

  private func seedFromCacheIfNeeded(isFirstPage: Bool, libraryIds: [String]) async {
    guard isFirstPage, !didSeedFromCache, pagination.isEmpty else { return }
    didSeedFromCache = true

    let cachedIds = sectionCache.ids(for: section)
    guard !cachedIds.isEmpty else { return }
    withAnimation(.easeInOut(duration: 0.18)) {
      pagination.items = cachedIds.map(IdentifiedString.init)
    }
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }
}
