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
            layout: .grid
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
            layout: .list
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
  }
}
