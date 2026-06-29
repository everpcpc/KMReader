//
// DashboardSectionView.swift
//
//

import SwiftUI

@MainActor
struct DashboardSectionView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("showDashboardSectionGradientBackground")
  private var showDashboardSectionGradientBackground: Bool =
    AppConfig.showDashboardSectionGradientBackground
  @Environment(\.colorScheme) private var colorScheme

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 20)
  @State private var isLoading = false
  @State private var didSeedFromCache = false
  @State private var hasLoadedInitial = false

  private let logger = AppLogger(.dashboard)
  private let sectionCacheStore = DashboardSectionCacheStore.shared

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
    ZStack {
      #if os(iOS) || os(macOS)
        if showDashboardSectionGradientBackground {
          LinearGradient(
            colors: backgroundColors,
            startPoint: .top,
            endPoint: .bottom
          ).ignoresSafeArea()
        }
      #endif

      VStack(alignment: .leading, spacing: 0) {
        NavigationLink(value: NavDestination.dashboardSectionDetail(section: section)) {
          HStack {
            Text(section.displayName)
              .font(.title2)
              .bold()
              .fontDesign(.serif)
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        .padding()
        #if os(macOS)
          .padding(.leading, 16)
        #endif
        .disabled(pagination.isEmpty)

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
            #if os(macOS)
              .padding(.leading, 16)
            #endif
          }
          .contentMargins(.horizontal, spacing, for: .scrollContent)
          .scrollClipDisabled()
          #if os(macOS)
            .macHorizontalScrollButtons(
              scrollProxy: proxy,
              itemIds: pagination.items.map(\.id)
            )
          #endif
        }
      }
    }
    .opacity(pagination.isEmpty ? 0 : 1)
    .frame(height: pagination.isEmpty ? 0 : nil)
    .onReceive(NotificationCenter.default.publisher(for: .dashboardSectionsShouldReload)) {
      notification in
      guard let command = DashboardSectionRefreshNotifier.reloadCommand(from: notification) else {
        return
      }
      handleReloadCommand(command)
    }
    .task {
      guard !hasLoadedInitial else { return }
      hasLoadedInitial = true
      await refresh()
    }
  }

  @ViewBuilder
  private func itemView(for itemId: String) -> some View {
    switch section.contentKind {
    case .books:
      BookQueryItemView(
        bookId: itemId,
        layout: .grid,
        showSeriesTitle: true,
        onItemMissing: {
          removeItem(id: itemId)
        }
      )
    case .series:
      SeriesQueryItemView(
        seriesId: itemId,
        layout: .grid,
        onItemMissing: {
          removeItem(id: itemId)
        }
      )
    case .collections, .readLists:
      EmptyView()
    }
  }

  private func refresh() async {
    withAnimation {
      pagination.reset()
    }
    await loadMore()
  }

  private func handleReloadCommand(_ command: DashboardSectionReloadCommand) {
    guard command.includes(section) else {
      logger.debug("Dashboard section \(section) skipping reload: targeted other sections")
      return
    }

    if command.source == .auto, pagination.currentPage > 1 {
      logger.debug(
        "Dashboard section \(section) skipping auto-refresh: deep in pagination (page \(pagination.currentPage))"
      )
      return
    }

    Task {
      logger.debug("Dashboard section \(section) reloading")
      await refresh()
    }
  }

  private func loadMore() async {
    guard pagination.hasMorePages, !isLoading else { return }
    withAnimation {
      isLoading = true
    }

    let libraryIds = dashboard.libraryIds
    let instanceId = AppConfig.current.instanceId
    let isFirstPage = pagination.currentPage == 0

    if !AppConfig.isOffline {
      await seedFromCacheIfNeeded(isFirstPage: isFirstPage)
    }

    if AppConfig.isOffline {
      let ids: [String]
      switch section.contentKind {
      case .books:
        ids = await section.fetchOfflineBookIds(
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      case .series:
        ids = await section.fetchOfflineSeriesIds(
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      case .collections, .readLists:
        ids = []
      }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
      updateWidgetDataIfNeeded(ids: ids, isFirstPage: isFirstPage, instanceId: instanceId)
    } else {
      do {
        switch section.contentKind {
        case .books:
          if let page = try await section.fetchBooks(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
            if isFirstPage {
              _ = sectionCacheStore.updateIfChanged(section: section, ids: ids)
              updateWidgetDataIfNeeded(books: page.content, instanceId: instanceId)
            }
            applyPage(ids: ids, moreAvailable: !page.last)
          }
        case .series:
          if let page = try await section.fetchSeries(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
            if isFirstPage {
              _ = sectionCacheStore.updateIfChanged(section: section, ids: ids)
              updateWidgetDataIfNeeded(series: page.content, instanceId: instanceId)
            }
            applyPage(ids: ids, moreAvailable: !page.last)
          }
        case .collections, .readLists:
          applyPage(ids: [], moreAvailable: false)
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  private func seedFromCacheIfNeeded(isFirstPage: Bool) async {
    guard isFirstPage, !didSeedFromCache, pagination.isEmpty else { return }
    didSeedFromCache = true

    let cachedIds = sectionCacheStore.ids(for: section)
    guard !cachedIds.isEmpty else { return }
    withAnimation {
      pagination.items = cachedIds.map(IdentifiedString.init)
    }
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)

    if pagination.currentPage == 0 {
      if pagination.items != wrappedIds {
        withAnimation {
          pagination.items = wrappedIds
        }
      }
    } else if !wrappedIds.isEmpty {
      withAnimation {
        pagination.items.append(contentsOf: wrappedIds)
      }
    }

    pagination.advance(moreAvailable: moreAvailable)
  }

  private func updateWidgetDataIfNeeded(books: [Book], instanceId: String) {
    section.widgetDataTarget?.update(books: books, instanceId: instanceId)
  }

  private func updateWidgetDataIfNeeded(series: [Series], instanceId: String) {
    section.widgetDataTarget?.update(series: series, instanceId: instanceId)
  }

  private func updateWidgetDataIfNeeded(ids: [String], isFirstPage: Bool, instanceId: String) {
    guard isFirstPage, let target = section.widgetDataTarget else { return }
    guard !instanceId.isEmpty else { return }

    Task {
      await target.update(ids: ids, instanceId: instanceId)
    }
  }

  private func removeItem(id: String) {
    withAnimation {
      _ = pagination.removeItems(withIDs: [id])
    }
  }
}
