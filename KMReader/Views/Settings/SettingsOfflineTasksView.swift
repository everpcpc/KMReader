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

  @Query private var books: [KomgaBook]

  init() {
    let instanceId = AppConfig.currentInstanceId
    _books = Query(
      filter: #Predicate<KomgaBook> { book in
        book.instanceId == instanceId && (
          book.downloadStatusRaw == "pending" ||
          book.downloadStatusRaw == "downloading" ||
          book.downloadStatusRaw == "failed"
        )
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

  var body: some View {
    List {
      Section {
        Toggle(isOn: Binding(
          get: { isPaused },
          set: { newValue in
            Task {
              if newValue {
                await OfflineManager.shared.pauseSync()
              } else {
                await OfflineManager.shared.resumeSync(instanceId: instanceId)
              }
            }
          }
        )) {
          Label(isPaused ? "Paused" : "Running", systemImage: isPaused ? "pause.circle.fill" : "play.circle.fill")
            .foregroundColor(isPaused ? .orange : .green)
        }
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
        Section("Failed") {
          ForEach(failedBooks) { book in
            OfflineTaskRow(book: book)
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
    .inlineNavigationBarTitle("Offline Tasks")
  }
}

struct OfflineTaskRow: View {
  let book: KomgaBook

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(book.name)
          .font(.headline)
          .lineLimit(1)

        switch book.downloadStatus {
        case .downloading(let progress):
          ProgressView(value: progress) {
            Text("Downloading \(Int(progress * 100))%")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        case .pending:
          Text("Pending in queue...")
            .font(.caption)
            .foregroundColor(.secondary)
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

      Button(role: .destructive) {
        Task {
          await OfflineManager.shared.cancelDownload(bookId: book.bookId)
          let instanceId = AppConfig.currentInstanceId
          await OfflineManager.shared.syncDownloadQueue(instanceId: instanceId)
        }
      } label: {
        Image(systemName: "xmark.circle")
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
  }
}
