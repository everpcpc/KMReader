//
// DashboardSectionDetailView.swift
//
//

import SwiftData
import SwiftUI

@MainActor
struct DashboardSectionDetailView: View {
  let section: DashboardSection

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardSectionDetailLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("isOffline") private var isOffline: Bool = false

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  @State private var isLoading = false
  @State private var isQueueingAllOffline = false
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

          if section.contentKind == .books {
            Button {
              queueAllBooksOffline()
            } label: {
              Label(
                String(localized: "dashboard.downloadAll", defaultValue: "Download All"),
                systemImage: "arrow.down.circle"
              )
            }
            .disabled(isOffline || isQueueingAllOffline)
            .padding(.horizontal)
          }
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
            if section.contentKind == .books {
              Button {
                queueAllBooksOffline()
              } label: {
                Label(
                  String(localized: "dashboard.downloadAll", defaultValue: "Download All"),
                  systemImage: "arrow.down.circle"
                )
              }
              .disabled(isOffline || isQueueingAllOffline)

              Divider()
            }

            LayoutModePicker(
              selection: $browseLayout,
              showGridDensity: true
            )
          } label: {
            if isQueueingAllOffline {
              LoadingIcon()
            } else {
              Image(systemName: "ellipsis")
            }
          }
        }
      }
    #endif
  }

  @ViewBuilder
  private var contentView: some View {
    switch section.contentKind {
    case .books:
      bookContentView
    case .series:
      seriesContentView
    case .collections, .readLists:
      EmptyView()
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
      switch section.contentKind {
      case .books:
        ids = section.fetchOfflineBookIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      case .series:
        ids = section.fetchOfflineSeriesIds(
          context: modelContext,
          libraryIds: libraryIds,
          offset: pagination.currentPage * pagination.pageSize,
          limit: pagination.pageSize
        )
      case .collections, .readLists:
        ids = []
      }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
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
            applyPage(ids: ids, moreAvailable: !page.last)
          }
        case .series:
          if let page = try await section.fetchSeries(
            libraryIds: libraryIds,
            page: pagination.currentPage,
            size: pagination.pageSize
          ) {
            let ids = page.content.map { $0.id }
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

  private func queueAllBooksOffline() {
    guard section.contentKind == .books, !isOffline else { return }
    guard !isQueueingAllOffline else { return }

    isQueueingAllOffline = true
    let libraryIds = dashboard.libraryIds
    let instanceId = AppConfig.current.instanceId

    Task {
      defer {
        Task { @MainActor in
          isQueueingAllOffline = false
        }
      }

      do {
        let result = try await queueAllBookPagesOffline(
          libraryIds: libraryIds,
          instanceId: instanceId
        )

        guard result.foundBooks else {
          ErrorManager.shared.notify(
            message: String(localized: "No books found to queue for offline reading.")
          )
          return
        }

        if result.queuedCount > 0 {
          OfflineManager.shared.triggerSync(instanceId: instanceId)
          ErrorManager.shared.notify(
            message: String(
              format: String(localized: "Queued %lld books for offline reading."),
              Int64(result.queuedCount)
            )
          )
        } else {
          ErrorManager.shared.notify(
            message: String(localized: "No new books were added to the offline queue.")
          )
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func queueAllBookPagesOffline(
    libraryIds: [String],
    instanceId: String,
    pageSize: Int = 100
  ) async throws -> (queuedCount: Int, foundBooks: Bool) {
    guard !instanceId.isEmpty else { return (0, false) }

    var pageIndex = 0
    var queuedCount = 0
    var foundBooks = false

    while true {
      guard
        let page = try await section.fetchBooks(
          libraryIds: libraryIds,
          page: pageIndex,
          size: pageSize
        )
      else {
        break
      }

      foundBooks = foundBooks || !page.content.isEmpty
      let ids = page.content.map(\.id)
      queuedCount +=
        await DatabaseOperator.databaseIfConfigured()?.queueBooksOffline(
          bookIds: ids,
          instanceId: instanceId
        ) ?? 0

      guard !page.last else { break }
      pageIndex += 1
    }

    return (queuedCount, foundBooks)
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }
}
