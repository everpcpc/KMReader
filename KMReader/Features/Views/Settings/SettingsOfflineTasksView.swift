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
  @AppStorage("notifyDownloadFailure") private var notifyDownloadFailure: Bool = true

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

        Toggle("Notify Download Failure", isOn: $notifyDownloadFailure)
      } header: {
        Text("Sync Status")
      } footer: {
        if isPaused {
          Text("Downloads are currently paused.")
        }
      }

      if !downloadingBooks.isEmpty {
        Section("Downloading") {
          ForEach(downloadingBooks) { book in
            OfflineTaskRow()
              .environment(book)
          }
        }
      }

      if !pendingBooks.isEmpty {
        Section("Pending") {
          ForEach(pendingBooks) { book in
            OfflineTaskRow()
              .environment(book)
          }
        }
      }

      if !failedBooks.isEmpty {
        Section("Failed") {
          ForEach(failedBooks) { book in
            OfflineTaskRow()
              .environment(book)
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
    .inlineNavigationBarTitle(String(localized: "Offline Tasks"))
    .animation(.default, value: isPaused)
    .onChange(of: isPaused) { _, newValue in
      if !newValue {
        OfflineManager.shared.triggerSync(instanceId: instanceId, restart: true)
      }
    }
  }
}

struct OfflineTaskRow: View {
  @Environment(KomgaBook.self) private var book

  private var progress: Double? {
    DownloadProgressTracker.shared.progress[book.bookId]
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(book.seriesTitle)
          .font(.caption)
          .lineLimit(1)
        Text(book.name)
          .font(.headline)
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
        Button(role: .destructive) {
          Task {
            await OfflineManager.shared.cancelDownload(bookId: book.bookId)
            let instanceId = AppConfig.currentInstanceId
            OfflineManager.shared.triggerSync(instanceId: instanceId)
          }
        } label: {
          Image(systemName: "xmark.circle")
            .foregroundColor(.red)
        }
        .buttonStyle(.plain)
      #endif
    }
    .padding(.vertical, 4)
  }
}
