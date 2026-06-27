//
// SeriesDetailView.swift
//
//

import Flow
import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("seriesDetailLayout") private var seriesDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss
  @Environment(\.readerActions) private var readerActions

  @State private var item: SeriesDisplayItem?
  @State private var bookViewModel = BookViewModel()
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false
  @State private var readingTargetBook: Book?
  @State private var readingTargetInstanceId: String?
  @State private var readingTargetIsOffline: Bool?
  @State private var isResolvingReadingTarget = false
  @State private var readingTargetResolutionID = 0
  @AppStorage("seriesBookBrowseOptions") private var seriesBookBrowseOptions: BookBrowseOptions =
    BookBrowseOptions()

  init(seriesId: String) {
    self.seriesId = seriesId
  }

  private var series: Series? {
    item?.series
  }

  private var canMarkSeriesAsRead: Bool {
    guard let series else { return false }
    return series.booksUnreadCount > 0
  }

  private var canMarkSeriesAsUnread: Bool {
    guard let series else { return false }
    return (series.booksReadCount + series.booksInProgressCount) > 0
  }

  private var canRead: Bool {
    guard let series, !series.deleted else { return false }
    return (series.booksUnreadCount + series.booksInProgressCount) > 0
  }

  private var readLabel: String {
    if isResumingReading {
      return String(localized: "Resume Reading")
    } else {
      return String(localized: "Start Reading")
    }
  }

  private var isResumingReading: Bool {
    series?.hasStartedReading == true
  }

  private var navigationTitle: String {
    series?.metadata.title ?? String(localized: "Series")
  }

  private var shareURL: URL? {
    KomgaWebLinkBuilder.series(serverURL: current.serverURL, seriesId: seriesId)
  }

  private var shouldShowReadingBar: Bool {
    canRead
  }

  private var readingTargetBookForCurrentContext: Book? {
    guard readingTargetInstanceId == current.instanceId, readingTargetIsOffline == isOffline else {
      return nil
    }
    return readingTargetBook
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading) {
        if let series = series {
          VStack(alignment: .leading) {
            #if os(tvOS)
              seriesToolbarContent
                .padding(.vertical, 8)
            #endif

            SeriesDetailContentView(series: series)

            if let item {
              SeriesCollectionsSection(collectionIds: item.collectionIds)
            }

            Divider()
            if let item {
              SeriesDownloadActionsSection(
                seriesId: item.seriesId,
                status: item.downloadStatus,
                policy: item.offlinePolicy,
                offlinePolicyLimit: item.offlinePolicyLimit,
                onMutationCompleted: {
                  Task {
                    await refreshSeriesData()
                  }
                }
              )
            }
            Divider()
          }
          .padding(.horizontal)

          if item != nil {
            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(navigationTitle)
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.series(serverURL: current.serverURL, seriesId: seriesId),
      scope: .browse
    )
    #if os(iOS) || os(macOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          seriesToolbarContent
        }
      }
    #endif
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if shouldShowReadingBar {
        SeriesReadingActionBar(
          actionTitle: readLabel,
          book: readingTargetBookForCurrentContext,
          fallbackTitle: navigationTitle,
          isResuming: isResumingReading,
          isResolving: isResolvingReadingTarget,
          action: {
            continueReading()
          }
        )
        .frame(maxWidth: 720)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
      }
    }
    .alert("Delete Series?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(series?.metadata.title ?? "this series") from Komga.")
    }
    .sheet(isPresented: $showCollectionPicker) {
      CollectionPickerSheet(
        seriesId: seriesId,
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      if let series = series {
        SeriesEditSheet(series: series)
          .onDisappear {
            Task {
              await refreshSeriesData()
            }
          }
      }
    }
    .sheet(isPresented: $showSavedFilters) {
      SavedFiltersView(filterType: .seriesBooks)
    }
    .task {
      await refreshSeriesData()
    }
    .onChange(of: current) {
      clearReadingTargetForContextChange()
      Task {
        await refreshSeriesData()
      }
    }
    .onChange(of: isOffline) {
      clearReadingTargetForContextChange()
      Task {
        await refreshReadingTargetBook()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .seriesProjectionDidChange)) {
      notification in
      guard shouldRefreshForSeriesProjection(notification) else { return }
      Task {
        await refreshLocalSeriesData()
        await refreshSeriesBooks()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookProjectionDidChange)) {
      notification in
      guard shouldRefreshForBookProjection(notification) else { return }
      Task {
        await refreshLocalSeriesData()
        await refreshSeriesBooks()
      }
    }
  }
}

extension SeriesDetailView {
  private func refreshSeriesData() async {
    await loadLocalSeries()
    do {
      _ = try await SyncService.syncSeriesDetail(seriesId: seriesId)
      await SyncService.syncSeriesCollections(seriesId: seriesId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if item == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
    await loadLocalSeries()
    await refreshReadingTargetBook()
  }

  private func refreshLocalSeriesData() async {
    await loadLocalSeries()
    await refreshReadingTargetBook()
  }

  private func refreshSeriesBooks() async {
    await bookViewModel.loadSeriesBooks(
      seriesId: seriesId,
      browseOpts: seriesBookBrowseOptions,
      refresh: true
    )
  }

  private func loadLocalSeries() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchSeriesDisplayItem(
      seriesId: seriesId,
      instanceId: current.instanceId
    )
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.analyzeSeries(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.analysisStarted"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func refreshSeriesMetadata() {
    Task {
      do {
        try await SeriesService.refreshMetadata(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.metadataRefreshed"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.markAsRead(seriesId: seriesId)
        _ = try? await SyncService.syncSeriesDetail(seriesId: seriesId)
        try? await SyncService.syncAllSeriesBooks(seriesId: seriesId)
        await ContentProjectionNotifier.postSeriesBooksDidChange(
          seriesId: seriesId,
          reason: .readingProgress
        )
        await DashboardSectionRefreshNotifier.postReadStatusChanged(
          source: .manual,
          reason: "Series read status changed"
        )
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.markAsUnread(seriesId: seriesId)
        _ = try? await SyncService.syncSeriesDetail(seriesId: seriesId)
        try? await SyncService.syncAllSeriesBooks(seriesId: seriesId)
        await ContentProjectionNotifier.postSeriesBooksDidChange(
          seriesId: seriesId,
          reason: .readingProgress
        )
        await DashboardSectionRefreshNotifier.postReadStatusChanged(
          source: .manual,
          reason: "Series read status changed"
        )
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        if let series {
          try await SeriesDeletionService.deleteSeries(series, instanceId: current.instanceId)
        } else {
          try await SeriesDeletionService.deleteSeries(
            seriesId: seriesId,
            instanceId: current.instanceId
          )
        }
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        dismiss()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func continueReading() {
    Task {
      let instanceId = current.instanceId
      let offline = isOffline
      let resolvedBook = await resolveReadingTargetBook(instanceId: instanceId, isOffline: offline)
      guard instanceId == current.instanceId, offline == isOffline else { return }
      updateReadingTarget(resolvedBook, instanceId: instanceId, isOffline: offline)

      if let book = resolvedBook {
        readerActions.open(book: book, incognito: false)
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        // Sync the collection to update its local series IDs
        _ = try? await SyncService.syncCollection(id: collectionId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.addedToCollection"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  @ViewBuilder
  private var seriesToolbarContent: some View {
    HStack {
      #if os(iOS) || os(macOS)
        if let shareURL {
          ShareLink(item: shareURL, subject: Text(navigationTitle)) {
            Image(systemName: "square.and.arrow.up")
          }
        }
      #endif

      Button {
        showSavedFilters = true
      } label: {
        Image(systemName: "bookmark")
      }

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      Menu {
        LayoutModePicker(selection: $seriesDetailLayout)

        Divider()

        if current.isAdmin {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button {
            analyzeSeries()
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }

          Button {
            refreshSeriesMetadata()
          } label: {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
          }
        }

        Divider()

        Button {
          showCollectionPicker = true
        } label: {
          Label("Add to Collection", systemImage: ContentIcon.collection)
        }

        if series != nil {
          if canMarkSeriesAsRead {
            Button {
              markSeriesAsRead()
            } label: {
              Label("Mark as Read", systemImage: "checkmark")
            }
          }

          if canMarkSeriesAsUnread {
            Button {
              markSeriesAsUnread()
            } label: {
              Label("Mark as Unread", systemImage: "circle")
            }
          }
        }

        Divider()

        if current.isAdmin {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Series", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
    }.toolbarButtonStyle()
  }

  private func refreshReadingTargetBook() async {
    readingTargetResolutionID += 1
    let resolutionID = readingTargetResolutionID
    let instanceId = current.instanceId
    let offline = isOffline

    if !isReadingTargetScoped(to: instanceId, isOffline: offline) {
      readingTargetBook = nil
    }
    readingTargetInstanceId = instanceId
    readingTargetIsOffline = offline

    guard canRead else {
      readingTargetBook = nil
      isResolvingReadingTarget = false
      return
    }

    isResolvingReadingTarget = true
    let book = await resolveReadingTargetBook(instanceId: instanceId, isOffline: offline)
    guard readingTargetResolutionID == resolutionID else { return }
    guard instanceId == current.instanceId, offline == isOffline else { return }
    guard !Task.isCancelled else {
      isResolvingReadingTarget = false
      return
    }
    updateReadingTarget(book, instanceId: instanceId, isOffline: offline)
    isResolvingReadingTarget = false
  }

  private func resolveReadingTargetBook(instanceId: String, isOffline: Bool) async -> Book? {
    guard canRead else { return nil }
    return await SeriesContinueReadingResolver.resolve(
      seriesId: seriesId,
      instanceId: instanceId,
      isOffline: isOffline
    )
  }

  private func updateReadingTarget(_ book: Book?, instanceId: String, isOffline: Bool) {
    readingTargetBook = book
    readingTargetInstanceId = instanceId
    readingTargetIsOffline = isOffline
  }

  private func clearReadingTargetForContextChange() {
    readingTargetResolutionID += 1
    readingTargetBook = nil
    readingTargetInstanceId = current.instanceId
    readingTargetIsOffline = isOffline
    isResolvingReadingTarget = false
  }

  private func isReadingTargetScoped(to instanceId: String, isOffline: Bool) -> Bool {
    readingTargetInstanceId == instanceId && readingTargetIsOffline == isOffline
  }

  private func shouldRefreshForBookProjection(_ notification: Notification) -> Bool {
    let changedIds = changedBookIds(from: notification)
    guard !changedIds.isEmpty else { return true }
    if let readingTargetBook = readingTargetBookForCurrentContext,
      changedIds.contains(readingTargetBook.id)
    {
      return true
    }
    let visibleBookIds = Set(bookViewModel.pagination.items.map(\.id))
    guard !visibleBookIds.isEmpty else { return true }
    return !changedIds.isDisjoint(with: visibleBookIds)
  }

  private func shouldRefreshForSeriesProjection(_ notification: Notification) -> Bool {
    let changedIds = changedSeriesIds(from: notification)
    guard !changedIds.isEmpty else { return true }
    return changedIds.contains(seriesId)
  }

  private func changedSeriesIds(from notification: Notification) -> Set<String> {
    if let ids = notification.userInfo?["seriesIds"] as? Set<String> {
      return ids
    }
    if let ids = notification.userInfo?["seriesIds"] as? [String] {
      return Set(ids)
    }
    if let id = notification.userInfo?["seriesId"] as? String {
      return [id]
    }
    return []
  }

  private func changedBookIds(from notification: Notification) -> Set<String> {
    if let ids = notification.userInfo?["bookIds"] as? Set<String> {
      return ids
    }
    if let ids = notification.userInfo?["bookIds"] as? [String] {
      return Set(ids)
    }
    if let id = notification.userInfo?["bookId"] as? String {
      return [id]
    }
    return []
  }
}
