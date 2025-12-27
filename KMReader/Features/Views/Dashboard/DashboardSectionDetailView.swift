//
//  DashboardSectionDetailView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardSectionDetailView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardSectionDetailLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var itemIds: [String] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false

  @Environment(\.modelContext) private var modelContext

  private let pageSize = 50

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
        ForEach(Array(itemIds.enumerated()), id: \.element) { index, bookId in
          BookQueryItemView(
            bookId: bookId,
            cardWidth: layoutHelper.cardWidth,
            layout: .grid,
            onBookUpdated: {
              Task { await loadItems(refresh: true) }
            },
            showSeriesTitle: true
          )
          .padding(.bottom)
          .onAppear {
            if index >= itemIds.count - 3 {
              Task { await loadItems(refresh: false) }
            }
          }
        }
      }
    case .list:
      LazyVStack {
        ForEach(Array(itemIds.enumerated()), id: \.element) { index, bookId in
          BookQueryItemView(
            bookId: bookId,
            cardWidth: layoutHelper.cardWidth,
            layout: .list,
            onBookUpdated: {
              Task { await loadItems(refresh: true) }
            },
            showSeriesTitle: true
          )
          .onAppear {
            if index >= itemIds.count - 3 {
              Task { await loadItems(refresh: false) }
            }
          }
          if index < itemIds.count - 1 {
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
        ForEach(Array(itemIds.enumerated()), id: \.element) { index, seriesId in
          SeriesQueryItemView(
            seriesId: seriesId,
            cardWidth: layoutHelper.cardWidth,
            layout: .grid,
            onActionCompleted: {
              Task { await loadItems(refresh: true) }
            }
          )
          .padding(.bottom)
          .onAppear {
            if index >= itemIds.count - 3 {
              Task { await loadItems(refresh: false) }
            }
          }
        }
      }
    case .list:
      LazyVStack {
        ForEach(Array(itemIds.enumerated()), id: \.element) { index, seriesId in
          SeriesQueryItemView(
            seriesId: seriesId,
            cardWidth: layoutHelper.cardWidth,
            layout: .list,
            onActionCompleted: {
              Task { await loadItems(refresh: true) }
            }
          )
          .onAppear {
            if index >= itemIds.count - 3 {
              Task { await loadItems(refresh: false) }
            }
          }
          if index < itemIds.count - 1 {
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
      currentPage = 0
      hasMore = true
    }
    guard hasMore else { return }

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

    isLoading = false
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
