//
// CollectionSeriesListView.swift
//
//

import SwiftUI

// Series list view for collection
struct CollectionSeriesListView: View {
  let collectionId: String
  let readerPresentation: ReaderPresentationManager
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("collectionDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("collectionSeriesBrowseOptions") private var browseOpts: CollectionSeriesBrowseOptions =
    CollectionSeriesBrowseOptions()
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var seriesViewModel = SeriesViewModel()
  @State private var selectedSeriesIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false
  @State private var collectionItem: CollectionDisplayItem?
  @State private var projectionRefreshTask: Task<Void, Never>?
  @State private var readerCloseRefreshTask: Task<Void, Never>?
  @State private var shouldRefreshAfterReading = false

  private static let localProjectionRefreshDelay: UInt64 = 750_000_000
  private static let remoteProjectionRefreshDelay: UInt64 = 5_000_000_000

  init(
    collectionId: String,
    readerPresentation: ReaderPresentationManager,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>
  ) {
    self.collectionId = collectionId
    self.readerPresentation = readerPresentation
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
  }

  private var isReaderActive: Bool {
    readerPresentation.currentSession != nil
  }

  private var supportsSelectionMode: Bool {
    #if os(tvOS)
      return false
    #else
      return true
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Series")
          .font(.headline)

        Spacer()

        HStack(spacing: 8) {
          CollectionSeriesFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            showSavedFilters: $showSavedFilters,
            collectionId: collectionId
          )

          if supportsSelectionMode && !isSelectionMode && current.isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil")
            }
            .adaptiveButtonStyle(.borderedProminent)
            .optimizedControlSize()
            .transition(.opacity.combined(with: .scale))
          }
        }
      }
      .padding(.horizontal)

      if supportsSelectionMode && isSelectionMode {
        SelectionToolbar(
          selectedCount: selectedSeriesIds.count,
          totalCount: collectionItem?.seriesCount ?? 0,
          isDeleting: isDeleting,
          onSelectAll: {
            if let seriesIds = collectionItem?.seriesIds {
              if selectedSeriesIds.count == seriesIds.count {
                selectedSeriesIds.removeAll()
              } else {
                selectedSeriesIds = Set(seriesIds)
              }
            }
          },
          onDelete: {
            Task {
              await deleteSelectedSeries()
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedSeriesIds.removeAll()
          }
        )
        .padding(.horizontal)
      }

      if collectionItem != nil {
        CollectionSeriesQueryView(
          collectionId: collectionId,
          seriesViewModel: seriesViewModel,
          browseOpts: browseOpts,
          browseLayout: layoutMode,
          isSelectionMode: isSelectionMode,
          selectedSeriesIds: $selectedSeriesIds,
          isAdmin: current.isAdmin
        )
      } else if seriesViewModel.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      }
    }
    .task(id: collectionId) {
      await refreshSeries()
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshSeries()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .seriesProjectionDidChange)) {
      notification in
      guard shouldRefreshForSeriesProjection(notification) else { return }
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
  }

  private func refreshSeries() async {
    await loadCollection()
    await seriesViewModel.loadCollectionSeries(
      collectionId: collectionId,
      browseOpts: browseOpts,
      refresh: true
    )
  }

  private func loadCollection() async {
    guard let database = try? await DatabaseOperator.database() else {
      collectionItem = nil
      return
    }
    collectionItem = try? await database.fetchCollectionDisplayItem(
      collectionId: collectionId,
      instanceId: current.instanceId
    )
  }

  private func deleteSelectedSeries() async {
    guard !selectedSeriesIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await CollectionService.removeSeriesFromCollection(
        collectionId: collectionId,
        seriesIds: Array(selectedSeriesIds)
      )
      // Sync the collection to update its local series IDs
      _ = try? await SyncService.syncCollection(id: collectionId)
      await loadCollection()

      ErrorManager.shared.notify(
        message: String(localized: "notification.series.removedFromCollection"))

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedSeriesIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the series list
      await refreshSeries()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func shouldRefreshForSeriesProjection(_ notification: Notification) -> Bool {
    let changedIds = changedSeriesIds(from: notification)
    guard !changedIds.isEmpty else { return true }
    guard let currentIds = collectionItem?.seriesIds else { return true }
    return !changedIds.isDisjoint(with: currentIds)
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
        await refreshSeries()
      }
      projectionRefreshTask = nil
    }
  }

  private func handleSSEEvent(_ info: SSEEventInfo) {
    guard AppConfig.enableSSEAutoRefresh else { return }

    switch info.type {
    case .readProgressChanged, .readProgressDeleted, .readProgressSeriesChanged,
      .readProgressSeriesDeleted, .seriesAdded, .seriesChanged, .seriesDeleted,
      .collectionChanged, .collectionDeleted:
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
      await refreshSeries()
      readerCloseRefreshTask = nil
    }
  }
}
