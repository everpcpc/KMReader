//
// OfflineTasksView.swift
//
//

import SQLiteData
import SwiftUI

struct OfflineTasksView: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  private var instanceId: String { current.instanceId }
  @AppStorage("offlinePaused") private var isPaused: Bool = false
  @AppStorage("offlineAutoDeleteRead") private var autoDeleteRead: Bool = false
  @State private var showingBulkAlert = false
  @State private var showingAutoDeleteAlert = false
  @State private var pendingBulkAction: BulkAction?

  enum BulkAction {
    case retryAll, cancelAll
  }

  @FetchAll private var books: [KomgaBookRecord]
  @FetchAll private var bookLocalStateList: [KomgaBookLocalStateRecord]

  private struct TaskItem: Identifiable {
    let book: KomgaBookRecord
    let localState: KomgaBookLocalStateRecord

    var id: String { book.bookId }
  }

  init() {
    let instanceId = AppConfig.current.instanceId
    _books = FetchAll(
      KomgaBookRecord.where { $0.instanceId.eq(instanceId) }
    )
    _bookLocalStateList = FetchAll(
      KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) }.order(by: \.bookId)
    )
  }

  private var taskItems: [TaskItem] {
    let bookIds = Set(books.map(\.bookId))
    let stateMap = Dictionary(
      bookLocalStateList
        .filter { bookIds.contains($0.bookId) }
        .map { ($0.bookId, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    let filtered = books.compactMap { book -> TaskItem? in
      let state = stateMap[book.bookId] ?? .empty(instanceId: book.instanceId, bookId: book.bookId)
      let status = state.downloadStatusRaw
      guard status == "pending" || status == "downloading" || status == "failed" else {
        return nil
      }
      return TaskItem(book: book, localState: state)
    }

    return filtered.sorted {
      switch ($0.localState.downloadAt, $1.localState.downloadAt) {
      case (let lhs?, let rhs?): return lhs < rhs
      case (nil, nil): return false
      case (nil, _): return false
      case (_, nil): return true
      }
    }
  }

  private var downloadingBooks: [TaskItem] {
    taskItems.filter { $0.localState.downloadStatusRaw == "downloading" }
  }

  private var pendingBooks: [TaskItem] {
    taskItems.filter { $0.localState.downloadStatusRaw == "pending" }
  }

  private var failedBooks: [TaskItem] {
    taskItems.filter { $0.localState.downloadStatusRaw == "failed" }
  }

  private var currentStatus: SyncStatus {
    if isPaused {
      return .paused
    }
    if !downloadingBooks.isEmpty {
      return .downloading
    }
    if !pendingBooks.isEmpty {
      return .syncing
    }
    return .idle
  }

  var body: some View {
    Form {
      Section {
        Toggle(
          isOn: Binding(
            get: { !isPaused },
            set: { newValue in
              isPaused = !newValue
            }
          )
        ) {
          Label(currentStatus.label, systemImage: currentStatus.icon)
            .foregroundColor(currentStatus.color)
        }

        Toggle(
          isOn: Binding(
            get: { autoDeleteRead },
            set: { newValue in
              if newValue {
                showingAutoDeleteAlert = true
              } else {
                autoDeleteRead = false
              }
            }
          )
        ) {
          Label(
            String(localized: "settings.offline.auto_delete_read"),
            systemImage: autoDeleteRead ? "checkmark.circle" : "circle"
          )
        }
      }

      if !downloadingBooks.isEmpty {
        Section("Downloading") {
          ForEach(downloadingBooks) { item in
            OfflineTaskRow(book: item.book, localState: item.localState)
          }
        }
      }

      if !pendingBooks.isEmpty {
        Section("Pending") {
          ForEach(pendingBooks) { item in
            OfflineTaskRow(book: item.book, localState: item.localState)
          }
        }
      }

      if !failedBooks.isEmpty {
        Section {
          ForEach(failedBooks) { item in
            OfflineTaskRow(book: item.book, localState: item.localState)
          }
        } header: {
          HStack {
            Text("Failed")
            Spacer()
            HStack(spacing: 8) {
              Button {
                pendingBulkAction = .retryAll
                showingBulkAlert = true
              } label: {
                Text("Retry All")
                  .font(.caption)
              }
              .adaptiveButtonStyle(.bordered)
              .tint(.blue)
              .buttonBorderShape(.capsule)
              .optimizedControlSize()

              Button {
                pendingBulkAction = .cancelAll
                showingBulkAlert = true
              } label: {
                Text("Cancel All")
                  .font(.caption)
              }
              .adaptiveButtonStyle(.bordered)
              .tint(.red)
              .buttonBorderShape(.capsule)
              .optimizedControlSize()
            }
          }
        }
      }

      if taskItems.isEmpty {
        ContentUnavailableView {
          Label("No Download Tasks", systemImage: "square.and.arrow.down")
        } description: {
          Text("No books are currently queued for offline reading.")
        }
        .tvFocusableHighlight()
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(OfflineSection.tasks.title)
    .animation(.default, value: isPaused)
    .animation(.default, value: currentStatus)
    .animation(.default, value: books)
    .alert(
      "Confirm Action", isPresented: $showingBulkAlert,
      presenting: pendingBulkAction
    ) { action in
      Button(role: .destructive) {
        Task {
          switch action {
          case .retryAll:
            await OfflineManager.shared.retryFailedDownloads(instanceId: instanceId)
            ErrorManager.shared.notify(
              message: String(localized: "notification.offline.retryAllFailed")
            )
          case .cancelAll:
            await OfflineManager.shared.cancelFailedDownloads(instanceId: instanceId)
            ErrorManager.shared.notify(
              message: String(localized: "notification.offline.cancelAllFailed")
            )
          }
        }
      } label: {
        Text(action == .retryAll ? "Retry All" : "Cancel All")
      }
      Button("Cancel", role: .cancel) {}
    } message: { action in
      Text(
        action == .retryAll
          ? "Are you sure you want to retry all failed downloads?"
          : "Are you sure you want to cancel all failed downloads?"
      )
    }
    .onChange(of: isPaused) { _, newValue in
      if newValue {
        // Pause: cancel all active background downloads
        #if os(iOS)
          BackgroundDownloadManager.shared.cancelAllDownloads()
        #endif
      } else {
        // Resume: trigger sync to restart downloads
        OfflineManager.shared.triggerSync(instanceId: instanceId, restart: true)
      }
    }
    .task {
      OfflineManager.shared.triggerSync(instanceId: instanceId)
    }
    .alert(
      String(localized: "settings.offline.auto_delete_read"),
      isPresented: $showingAutoDeleteAlert
    ) {
      Button(String(localized: "Cancel"), role: .cancel) {}
      Button(String(localized: "Confirm"), role: .destructive) {
        autoDeleteRead = true
        isPaused = true
        ErrorManager.shared.notify(
          message: String(localized: "notification.offline.autoDeleteReadEnabled")
        )
      }
    } message: {
      Text(String(localized: "settings.offline.auto_delete_read.message"))
    }
  }
}

struct OfflineTaskRow: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  private var instanceId: String { current.instanceId }
  let book: KomgaBookRecord
  let localState: KomgaBookLocalStateRecord

  private var progress: Double? {
    DownloadProgressTracker.shared.progress[book.bookId]
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(book.seriesTitle)
          .font(.caption)
          .lineLimit(1)
        Text("#\(book.metaNumber) - \(book.metaTitle)")
          .lineLimit(1)

        switch localState.downloadStatus {
        case .pending:
          if let progress = progress {
            ProgressView(value: progress) {
              Text("Downloading \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          } else {
            Text("Pending in queue...")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        case .failed(let error):
          Text(error)
            .font(.caption)
            .foregroundColor(.red)
            .lineLimit(2)
        default:
          EmptyView()
        }
      }

      Spacer()

      #if !os(tvOS)
        HStack(spacing: 16) {
          if case .failed = localState.downloadStatus {
            Button {
              Task {
                await OfflineManager.shared.retryDownload(
                  instanceId: instanceId, bookId: book.bookId)
              }
            } label: {
              Image(systemName: "arrow.clockwise.circle")
                .foregroundColor(.blue)
            }
            .adaptiveButtonStyle(.plain)
          }

          Button(role: .destructive) {
            Task {
              await OfflineManager.shared.cancelDownload(bookId: book.bookId)
              OfflineManager.shared.triggerSync(instanceId: instanceId)
            }
          } label: {
            Image(systemName: localState.downloadStatusRaw == "failed" ? "trash" : "xmark.circle")
              .foregroundColor(.red)
          }
          .adaptiveButtonStyle(.plain)
        }
      #endif
    }
    .padding(.vertical, 4)
  }
}
