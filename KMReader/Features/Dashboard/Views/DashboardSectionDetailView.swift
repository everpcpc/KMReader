//
//  DashboardSectionDetailView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

@MainActor
struct DashboardSectionDetailView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardSectionDetailLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  @State private var isLoading = false
  @State private var hasLoadedInitial = false
  @State private var bookCache: [String: KomgaBook] = [:]
  @State private var seriesCache: [String: KomgaSeries] = [:]

  @Environment(\.modelContext) private var modelContext

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {

        #if os(tvOS)
          Picker("Layout", selection: $browseLayout) {
            ForEach(BrowseLayoutMode.allCases, id: \.self) { layout in
              Image(systemName: layout.iconName)
            }
          }
          .pickerStyle(.segmented)
          .padding()
        #endif

        contentView
          .padding(.horizontal)
      }
    }
    .animation(.default, value: browseLayout)
    .inlineNavigationBarTitle(section.displayName)
    .task {
      guard !hasLoadedInitial else { return }
      hasLoadedInitial = true
      await loadItems(refresh: true)
    }
    .refreshable {
      await loadItems(refresh: true)
    }
    #if os(iOS) || os(macOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Menu {
            LayoutModePicker(
              selection: $browseLayout,
              showGridDensity: true
            )
          } label: {
            Image(systemName: "ellipsis")
          }
          .appMenuStyle()
        }
      }
    #endif
  }

  @ViewBuilder
  private var contentView: some View {
    if section.isBookSection {
      bookContentView
    } else {
      seriesContentView
    }
  }

  @ViewBuilder
  private var bookContentView: some View {
    switch browseLayout {
    case .grid:
      LazyVGrid(columns: columns, spacing: spacing) {
        ForEach(pagination.items) { book in
          BookQueryItemView(
            bookId: book.id,
            layout: .grid,
            komgaBook: bookCache[book.id],
            showSeriesTitle: true
          )
          .padding(.bottom)
          .onAppear {
            if pagination.shouldLoadMore(after: book) {
              Task { await loadItems(refresh: false) }
            }
          }
        }
      }
    case .list:
      LazyVStack {
        ForEach(pagination.items) { book in
          BookQueryItemView(
            bookId: book.id,
            layout: .list,
            komgaBook: bookCache[book.id],
            showSeriesTitle: true
          )
          .onAppear {
            if pagination.shouldLoadMore(after: book) {
              Task { await loadItems(refresh: false) }
            }
          }
          if !pagination.isLast(book) {
            Divider()
          }
        }
      }
    }
  }

  @ViewBuilder
  private var seriesContentView: some View {
    switch browseLayout {
    case .grid:
      LazyVGrid(columns: columns, spacing: spacing) {
        ForEach(pagination.items) { series in
          SeriesQueryItemView(
            seriesId: series.id,
            layout: .grid,
            komgaSeries: seriesCache[series.id]
          )
          .padding(.bottom)
          .onAppear {
            if pagination.shouldLoadMore(after: series) {
              Task { await loadItems(refresh: false) }
            }
          }
        }
      }
    case .list:
      LazyVStack {
        ForEach(pagination.items) { series in
          SeriesQueryItemView(
            seriesId: series.id,
            layout: .list,
            komgaSeries: seriesCache[series.id]
          )
          .onAppear {
            if pagination.shouldLoadMore(after: series) {
              Task { await loadItems(refresh: false) }
            }
          }
          if !pagination.isLast(series) {
            Divider()
          }
        }
      }
    }
  }

  func loadItems(refresh: Bool) async {
    guard !isLoading else { return }
    guard refresh || pagination.hasMorePages else { return }

    isLoading = true
    if refresh {
      pagination.reset()
      resetItemCache()
    }

    let libraryIds = dashboard.libraryIds

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
            applyPage(ids: ids, moreAvailable: !page.last)
          }
        } else {
          if let page = try await section.fetchSeries(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
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

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
    cacheItems(ids: ids)
  }

  private func resetItemCache() {
    bookCache.removeAll()
    seriesCache.removeAll()
  }

  private func cacheItems(ids: [String]) {
    guard !ids.isEmpty else { return }
    let instanceId = AppConfig.current.instanceId

    if section.isBookSection {
      let missing = ids.filter { bookCache[$0] == nil }
      guard !missing.isEmpty else { return }
      let books = KomgaBookStore.fetchBooksByIds(
        context: modelContext,
        ids: missing,
        instanceId: instanceId
      )
      for book in books {
        bookCache[book.bookId] = book
      }
    } else {
      let missing = ids.filter { seriesCache[$0] == nil }
      guard !missing.isEmpty else { return }
      let seriesList = KomgaSeriesStore.fetchSeriesByIds(
        context: modelContext,
        ids: missing,
        instanceId: instanceId
      )
      for series in seriesList {
        seriesCache[series.seriesId] = series
      }
    }
  }
}
