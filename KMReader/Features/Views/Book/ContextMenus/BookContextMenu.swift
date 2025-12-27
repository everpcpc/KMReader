//
//  BookContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

@MainActor
struct BookContextMenu: View {
  @Bindable var komgaBook: KomgaBook

  var onReadBook: ((Bool) -> Void)?
  var onActionCompleted: (() -> Void)? = nil
  var onShowReadListPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  var showSeriesNavigation: Bool = true

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var book: Book {
    komgaBook.toBook()
  }

  private var downloadStatus: DownloadStatus {
    komgaBook.downloadStatus
  }

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
  }

  var body: some View {
    Group {
      ControlGroup {
        NavigationLink(value: NavDestination.bookDetail(bookId: book.id)) {
          Label("Details", systemImage: "info.circle")
        }

        if let onReadBook = onReadBook {
          Button {
            onReadBook(true)
          } label: {
            Label("Read Incognito", systemImage: "eye.slash")
          }
        }

        if showSeriesNavigation {
          NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
            Label("Series", systemImage: "book")
          }
        }
      }

      Button {
        onShowReadListPicker?()
      } label: {
        Label("Add to Read List", systemImage: "list.bullet")
      }
      .disabled(isOffline)

      if !isCompleted {
        Button {
          markAsRead(bookId: book.id)
        } label: {
          Label("Mark as Read", systemImage: "checkmark.circle")
        }
        .disabled(isOffline)
      }
      if book.readProgress != nil {
        Button {
          markAsUnread(bookId: book.id)
        } label: {
          Label("Mark as Unread", systemImage: "circle")
        }
        .disabled(isOffline)
      }

      Divider()

      Button {
        Task {
          await OfflineManager.shared.toggleDownload(
            instanceId: currentInstanceId, info: book.downloadInfo)
        }
      } label: {
        Label(downloadStatus.menuLabel, systemImage: downloadStatus.menuIcon)
      }

      Divider()

      Menu {
        Button {
          onEditRequested?()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .disabled(!isAdmin || isOffline)

        Button {
          analyzeBook(bookId: book.id)
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(!isAdmin || isOffline)

        Button {
          refreshMetadata(bookId: book.id)
        } label: {
          Label("Refresh Metadata", systemImage: "arrow.clockwise")
        }
        .disabled(!isAdmin || isOffline)

        Divider()

        Button(role: .destructive) {
          Task {
            await CacheManager.clearCache(forBookId: book.id)
          }
        } label: {
          Label("Clear Cache", systemImage: "xmark.circle")
        }
      } label: {
        Label("Manage", systemImage: "gearshape")
      }
    }
  }

  private func markAsRead(bookId: String) {
    Task {
      do {
        try await BookService.shared.markAsRead(bookId: bookId)
        _ = try await SyncService.shared.syncBook(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markAsUnread(bookId: String) {
    Task {
      do {
        try await BookService.shared.markAsUnread(bookId: bookId)
        _ = try await SyncService.shared.syncBook(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func analyzeBook(bookId: String) {
    Task {
      do {
        try await BookService.shared.analyzeBook(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.analysisStarted"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func refreshMetadata(bookId: String) {
    Task {
      do {
        try await BookService.shared.refreshMetadata(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.metadataRefreshed"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func addToReadList(readListId: String, bookId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [bookId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.booksAddedToReadList"))
          onActionCompleted?()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
