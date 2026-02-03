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

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("dashboardShowGradient") private var dashboardShowGradient: Bool = true
  @Environment(DashboardSectionCacheStore.self) private var sectionCacheStore
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 20)
  @State private var isLoading = false
  @State private var didSeedFromCache = false
  @State private var isHoveringScrollArea = false
  @State private var hoverShowDelayTask: Task<Void, Never>?
  @State private var hoverHideDelayTask: Task<Void, Never>?
  @State private var hasLoadedInitial = false

  private let logger = AppLogger(.dashboard)

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
        if dashboardShowGradient {
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
            .overlay {
              HorizontalScrollButtons(
                scrollProxy: proxy,
                itemIds: pagination.items.map(\.id),
                isVisible: isHoveringScrollArea
              )
            }
          #endif
        }
      }
    }
    #if os(macOS)
      .onContinuousHover { phase in
        switch phase {
        case .active:
          hoverHideDelayTask?.cancel()
          hoverHideDelayTask = nil
          hoverShowDelayTask?.cancel()
          hoverShowDelayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
              isHoveringScrollArea = true
            }
          }
        case .ended:
          hoverShowDelayTask?.cancel()
          hoverShowDelayTask = nil
          hoverHideDelayTask?.cancel()
          hoverHideDelayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
              isHoveringScrollArea = false
            }
          }
        }
      }
    #endif
    .opacity(pagination.isEmpty ? 0 : 1)
    .frame(height: pagination.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) { _, newTrigger in
      // Skip if targeted refresh excludes this section
      if let sections = newTrigger.sectionsToRefresh, !sections.contains(section) {
        logger.debug("Dashboard section \(section) skipping refresh: targeted other sections")
        return
      }

      if newTrigger.source == .auto, pagination.currentPage > 1 {
        logger.debug(
          "Dashboard section \(section) skipping auto-refresh: deep in pagination (page \(pagination.currentPage))"
        )
        return
      }
      Task {
        logger.debug("Dashboard section \(section) refreshing")
        await refresh()
      }
    }
    .task {
      guard !hasLoadedInitial else { return }
      hasLoadedInitial = true
      await refresh()
    }
  }

  @ViewBuilder
  private func itemView(for itemId: String) -> some View {
    if section.isBookSection {
      BookQueryItemView(
        bookId: itemId,
        layout: .grid,
        showSeriesTitle: true
      )
    } else {
      SeriesQueryItemView(
        seriesId: itemId,
        layout: .grid
      )
    }
  }

  private func refresh() async {
    pagination.reset()
    await loadMore()
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
              _ = sectionCacheStore.updateIfChanged(section: section, ids: ids)
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
              _ = sectionCacheStore.updateIfChanged(section: section, ids: ids)
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

    let cachedIds = sectionCacheStore.ids(for: section)
    guard !cachedIds.isEmpty else { return }
    pagination.items = cachedIds.map(IdentifiedString.init)
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }
}
