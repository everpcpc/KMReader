//
//  SettingsOfflineTasksView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsOfflineTasksView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage("currentInstanceId") private var instanceId: String = ""
  @AppStorage("offlinePaused") private var isPaused: Bool = false
  @State private var showingBulkAlert = false
  @State private var pendingBulkAction: BulkAction?

  enum BulkAction {
    case retryAll, cancelAll
  }

  @Query private var books: [KomgaBook]

  init() {
    let instanceId = AppConfig.currentInstanceId
    _books = Query(
      filter: #Predicate<KomgaBook> { book in
        book.instanceId == instanceId
          && (book.downloadStatusRaw == "pending" || book.downloadStatusRaw == "downloading"
            || book.downloadStatusRaw == "failed")
      },
      sort: [SortDescriptor(\KomgaBook.downloadAt, order: .forward)]
    )
  }

  private var downloadingBooks: [KomgaBook] {
    books.filter { $0.downloadStatusRaw == "downloading" }
  }

  private var pendingBooks: [KomgaBook] {
    books.filter { $0.downloadStatusRaw == "pending" }
  }

  private var failedBooks: [KomgaBook] {
    books.filter { $0.downloadStatusRaw == "failed" }
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
    List {
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

      }

      if !downloadingBooks.isEmpty {
        Section("Downloading") {
          ForEach(downloadingBooks) { book in
            OfflineTaskRow(book: book)
          }
        }
      }

      if !pendingBooks.isEmpty {
        Section("Pending") {
          ForEach(pendingBooks) { book in
            OfflineTaskRow(book: book)
          }
        }
      }

      if !failedBooks.isEmpty {
        Section {
          ForEach(failedBooks) { book in
            OfflineTaskRow(book: book)
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
              .controlSize(.mini)

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
              .controlSize(.mini)
            }
          }
        }
      }

      if books.isEmpty {
        ContentUnavailableView {
          Label("No Offline Tasks", systemImage: "square.and.arrow.down")
        } description: {
          Text("No books are currently queued for offline reading.")
        }
      }
    }
    .inlineNavigationBarTitle(SettingsSection.offlineTasks.title)
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
          case .cancelAll:
            await OfflineManager.shared.cancelFailedDownloads(instanceId: instanceId)
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
  }
}

struct OfflineTaskRow: View {
  @AppStorage("currentInstanceId") private var instanceId: String = ""
  @Bindable var book: KomgaBook

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

        switch book.downloadStatus {
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
          if case .failed = book.downloadStatus {
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
            Image(systemName: book.downloadStatusRaw == "failed" ? "trash" : "xmark.circle")
              .foregroundColor(.red)
          }
          .adaptiveButtonStyle(.plain)
        }
      #endif
    }
    .padding(.vertical, 4)
  }
}
