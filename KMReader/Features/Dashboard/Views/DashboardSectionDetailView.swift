//
// DashboardSectionDetailView.swift
//
//

import SwiftUI

@MainActor
struct DashboardSectionDetailView: View {
  let section: DashboardSection
  let readerPresentation: ReaderPresentationManager

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardSectionDetailLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("isOffline") private var isOffline: Bool = false

  @State private var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  @State private var isLoading = false
  @State private var isQueueingAllOffline = false
  @State private var hasLoadedInitial = false
  @State private var projectionRefreshTask: Task<Void, Never>?
  @State private var readerCloseRefreshTask: Task<Void, Never>?
  @State private var shouldRefreshAfterReading = false
  @State private var needsRefreshAfterCurrentLoad = false

  private static let localProjectionRefreshDelay: UInt64 = 750_000_000
  private static let remoteProjectionRefreshDelay: UInt64 = 5_000_000_000

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  private var isReaderActive: Bool {
    readerPresentation.currentSession != nil
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

          if section.supportsDownloadAll {
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
    .onReceive(NotificationCenter.default.publisher(for: .bookProjectionDidChange)) { _ in
      guard section.contentKind == .books else { return }
      scheduleProjectionRefresh()
    }
    .onReceive(NotificationCenter.default.publisher(for: .seriesProjectionDidChange)) { _ in
      guard section.contentKind == .series else { return }
      scheduleProjectionRefresh()
    }
    .onReceive(NotificationCenter.default.publisher(for: .sseEventReceived)) { notification in
      guard let info = notification.userInfo?["info"] as? SSEEventInfo else { return }
      handleSSEEvent(info)
    }
    .onChange(of: readerPresentation.currentSession) { oldSession, newSession in
      handleReaderSessionChange(oldSession: oldSession, newSession: newSession)
    }
    .onDisappear {
      projectionRefreshTask?.cancel()
      projectionRefreshTask = nil
      readerCloseRefreshTask?.cancel()
      readerCloseRefreshTask = nil
    }
    #if os(iOS) || os(macOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Menu {
            if section.supportsDownloadAll {
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
    guard !isLoading else {
      if refresh {
        needsRefreshAfterCurrentLoad = true
      }
      return
    }
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

    finishLoading()
  }

  private func finishLoading() {
    withAnimation {
      isLoading = false
    }

    guard needsRefreshAfterCurrentLoad else { return }
    needsRefreshAfterCurrentLoad = false
    Task {
      await loadItems(refresh: true)
    }
  }

  private func scheduleProjectionRefresh(after delay: UInt64 = Self.localProjectionRefreshDelay) {
    projectionRefreshTask?.cancel()
    projectionRefreshTask = nil

    if isReaderActive {
      shouldRefreshAfterReading = true
      return
    }

    projectionRefreshTask = Task { @MainActor in
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      if isReaderActive {
        shouldRefreshAfterReading = true
      } else {
        await loadItems(refresh: true)
      }
      projectionRefreshTask = nil
    }
  }

  private func handleSSEEvent(_ info: SSEEventInfo) {
    guard AppConfig.enableSSEAutoRefresh else { return }

    switch info.type {
    case .readProgressChanged, .readProgressDeleted, .readProgressSeriesChanged,
      .readProgressSeriesDeleted:
      scheduleProjectionRefresh(after: Self.remoteProjectionRefreshDelay)
    case .bookAdded, .bookChanged, .bookDeleted, .bookImported:
      guard section.contentKind == .books else { return }
      scheduleProjectionRefresh(after: Self.remoteProjectionRefreshDelay)
    case .seriesAdded, .seriesChanged, .seriesDeleted:
      guard section.contentKind == .series else { return }
      scheduleProjectionRefresh(after: Self.remoteProjectionRefreshDelay)
    default:
      break
    }
  }

  private func handleReaderSessionChange(oldSession: ReaderSession?, newSession: ReaderSession?) {
    if newSession != nil {
      if projectionRefreshTask != nil {
        shouldRefreshAfterReading = true
      }
      projectionRefreshTask?.cancel()
      projectionRefreshTask = nil
      readerCloseRefreshTask?.cancel()
      readerCloseRefreshTask = nil
      return
    }

    guard oldSession != nil else { return }
    let needsRefresh = shouldRefreshAfterReading
    shouldRefreshAfterReading = false
    guard needsRefresh else { return }

    let visitedBookIds = oldSession?.visitedBookIds ?? []
    readerCloseRefreshTask?.cancel()
    readerCloseRefreshTask = Task { @MainActor in
      if !visitedBookIds.isEmpty {
        _ = await ReaderProgressDispatchService.shared.waitUntilSettled(
          bookIds: visitedBookIds,
          timeout: .seconds(5)
        )
      }

      guard !Task.isCancelled else { return }
      await loadItems(refresh: true)
      readerCloseRefreshTask = nil
    }
  }

  private func queueAllBooksOffline() {
    guard section.supportsDownloadAll, !isOffline else { return }
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
