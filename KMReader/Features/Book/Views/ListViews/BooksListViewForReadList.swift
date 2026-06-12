//
// BooksListViewForReadList.swift
//
//

import SwiftUI

// Books list view for read list
struct BooksListViewForReadList: View {
  let readListId: String
  let readerPresentation: ReaderPresentationManager
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("readListDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("readListBookBrowseOptions") private var browseOpts: ReadListBookBrowseOptions =
    ReadListBookBrowseOptions()
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var bookViewModel = BookViewModel()
  @State private var selectedBookIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false
  @State private var readListItem: ReadListDisplayItem?
  @State private var projectionRefreshTask: Task<Void, Never>?
  @State private var readerCloseRefreshTask: Task<Void, Never>?
  @State private var shouldRefreshAfterReading = false

  private static let localProjectionRefreshDelay: UInt64 = 750_000_000
  private static let remoteProjectionRefreshDelay: UInt64 = 5_000_000_000

  private var readListContext: ReaderReadListContext? {
    guard let readListItem else { return nil }
    return ReaderReadListContext(id: readListItem.readListId, name: readListItem.name)
  }

  private var isReaderActive: Bool {
    readerPresentation.currentSession != nil
  }

  init(
    readListId: String,
    readerPresentation: ReaderPresentationManager,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>
  ) {
    self.readListId = readListId
    self.readerPresentation = readerPresentation
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
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
        Text("Books")
          .font(.headline)

        Button {
          Task {
            await refreshBooks()
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(bookViewModel.isLoading)
        .adaptiveButtonStyle(.bordered)
        .optimizedControlSize()

        Spacer()

        HStack(spacing: 8) {
          ReadListBookFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            showSavedFilters: $showSavedFilters,
            readListId: readListId
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
          selectedCount: selectedBookIds.count,
          totalCount: readListItem?.bookCount ?? 0,
          isDeleting: isDeleting,
          onSelectAll: {
            if let bookIds = readListItem?.bookIds {
              if selectedBookIds.count == bookIds.count {
                selectedBookIds.removeAll()
              } else {
                selectedBookIds = Set(bookIds)
              }
            }
          },
          onDelete: {
            Task {
              await deleteSelectedBooks()
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedBookIds.removeAll()
          }
        )
        .padding(.horizontal)
      }

      if readListItem != nil {
        ReadListBooksQueryView(
          readListId: readListId,
          readListContext: readListContext,
          bookViewModel: bookViewModel,
          browseOpts: browseOpts,
          browseLayout: layoutMode,
          isSelectionMode: isSelectionMode,
          selectedBookIds: $selectedBookIds,
          isAdmin: current.isAdmin,
          refreshBooks: {
            Task {
              await refreshBooks()
            }
          }
        )
      } else if bookViewModel.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      }
    }
    .task(id: readListId) {
      await refreshBooks()
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshBooks()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookProjectionDidChange)) {
      notification in
      guard shouldRefreshForBookProjection(notification) else { return }
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

  private func refreshBooks() async {
    await loadReadList()
    await bookViewModel.loadReadListBooks(
      readListId: readListId,
      browseOpts: browseOpts,
      refresh: true
    )
  }

  private func loadReadList() async {
    guard let database = try? await DatabaseOperator.database() else {
      readListItem = nil
      return
    }
    readListItem = try? await database.fetchReadListDisplayItem(
      readListId: readListId,
      instanceId: current.instanceId
    )
  }

  private func deleteSelectedBooks() async {
    guard !selectedBookIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await ReadListService.removeBooksFromReadList(
        readListId: readListId,
        bookIds: Array(selectedBookIds)
      )
      // Sync the readlist to update its bookIds in local SwiftData
      _ = try? await SyncService.syncReadList(id: readListId)
      await loadReadList()

      ErrorManager.shared.notify(message: String(localized: "notification.readList.booksRemoved"))

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedBookIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the books list
      await refreshBooks()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func shouldRefreshForBookProjection(_ notification: Notification) -> Bool {
    let changedIds = changedBookIds(from: notification)
    guard !changedIds.isEmpty else { return true }
    guard let currentIds = readListItem?.bookIds else { return true }
    return !changedIds.isDisjoint(with: currentIds)
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
        await refreshBooks()
      }
      projectionRefreshTask = nil
    }
  }

  private func handleSSEEvent(_ info: SSEEventInfo) {
    guard AppConfig.enableSSEAutoRefresh else { return }

    switch info.type {
    case .readProgressChanged, .readProgressDeleted, .readProgressSeriesChanged,
      .readProgressSeriesDeleted, .bookChanged, .bookDeleted, .readListChanged,
      .readListDeleted:
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
      await refreshBooks()
      readerCloseRefreshTask = nil
    }
  }
}
