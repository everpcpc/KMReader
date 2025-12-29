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
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  @State private var isLoading = false

  @Environment(\.modelContext) private var modelContext

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        Picker("Layout", selection: $browseLayout) {
          ForEach(BrowseLayoutMode.allCases, id: \.self) { layout in
            Image(systemName: layout.iconName)
          }
        }
        .pickerStyle(.segmented)
        .padding()

        contentView
          .padding(.horizontal, layoutHelper.spacing)
      }
      .onChange(of: geometry.size.width, initial: true) { _, newWidth in
        updateLayoutHelper(width: newWidth)
      }
    }
    .animation(.default, value: browseLayout)
    .inlineNavigationBarTitle(section.displayName)
    .task {
      await loadItems(refresh: true)
    }
    .refreshable {
      await loadItems(refresh: true)
    }
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
      LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
        ForEach(pagination.items) { book in
          BookQueryItemView(
            bookId: book.id,
            cardWidth: layoutHelper.cardWidth,
            layout: .grid,
            onBookUpdated: {
              Task { await loadItems(refresh: true) }
            },
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
            cardWidth: layoutHelper.cardWidth,
            layout: .list,
            onBookUpdated: {
              Task { await loadItems(refresh: true) }
            },
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
      LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
        ForEach(pagination.items) { series in
          SeriesQueryItemView(
            seriesId: series.id,
            cardWidth: layoutHelper.cardWidth,
            layout: .grid,
            onActionCompleted: {
              Task { await loadItems(refresh: true) }
            }
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
            cardWidth: layoutHelper.cardWidth,
            layout: .list,
            onActionCompleted: {
              Task { await loadItems(refresh: true) }
            }
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

  private func updateLayoutHelper(width: CGFloat) {
    #if os(tvOS)
      layoutHelper = BrowseLayoutHelper(
        width: width, spacing: BrowseLayoutHelper.defaultSpacing,
        browseColumns: BrowseColumns())
    #else
      layoutHelper = BrowseLayoutHelper(
        width: width, spacing: BrowseLayoutHelper.defaultSpacing,
        browseColumns: browseColumns)
    #endif
  }

  private func loadItems(refresh: Bool) async {
    guard !isLoading else { return }
    if refresh {
      pagination.reset()
    }
    guard pagination.hasMorePages else { return }

    isLoading = true

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

    isLoading = false
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }
}
