//
//  BookContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookContextMenu: View {
  let book: Book
  let downloadStatus: DownloadStatus

  var onReadBook: ((Bool) -> Void)?
  var onShowReadListPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  var showSeriesNavigation: Bool = true

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
  }

  private var menuTitle: String {
    if book.oneshot {
      return book.metadata.title
    }
    let number = book.metadata.number
    if number.isEmpty {
      return book.metadata.title
    }
    return "#\(number) - \(book.metadata.title)"
  }

  var body: some View {
    Group {
      Button(action: {}) {
        Text(menuTitle.isEmpty ? "Untitled" : menuTitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .disabled(true)
      Divider()

      detailsSection

      if !isOffline {
        Button {
          onShowReadListPicker?()
        } label: {
          Label("Add to Read List", systemImage: ContentIcon.readList)
        }
        if !isCompleted {
          Button {
            markAsRead(bookId: book.id)
          } label: {
            Label("Mark as Read", systemImage: "checkmark.circle")
          }
        }
        if book.readProgress != nil {
          Button {
            markAsUnread(bookId: book.id)
          } label: {
            Label("Mark as Unread", systemImage: "circle")
          }
        }
        Divider()

        if current.isAdmin {
          Menu {
            Button {
              onEditRequested?()
            } label: {
              Label("Edit", systemImage: "pencil")
            }
            Button {
              analyzeBook(bookId: book.id)
            } label: {
              Label("Analyze", systemImage: "waveform.path.ecg")
            }
            Button {
              refreshMetadata(bookId: book.id)
            } label: {
              Label("Refresh Metadata", systemImage: "arrow.clockwise")
            }
            Divider()
          } label: {
            Label("Manage", systemImage: "gearshape")
          }
          Divider()
        }
      }

      Button {
        Task {
          let previousStatus = downloadStatus
          await OfflineManager.shared.toggleDownload(
            instanceId: current.instanceId, info: book.downloadInfo)
          await MainActor.run {
            ErrorManager.shared.notify(
              message: downloadNotificationMessage(for: previousStatus)
            )
          }
        }
      } label: {
        Label(downloadStatus.menuLabel, systemImage: downloadStatus.menuIcon)
      }

      if !isOffline {
        Divider()
        Button {
          refreshCover()
        } label: {
          Label("Refresh Cover", systemImage: "arrow.clockwise")
        }
      }

      if book.isDivina {
        Divider()
        Button(role: .destructive) {
          Task {
            await CacheManager.clearCache(forBookId: book.id)
            await MainActor.run {
              ErrorManager.shared.notify(message: String(localized: "notification.book.cacheCleared"))
            }
          }
        } label: {
          Label("Clear Cache", systemImage: "xmark.circle")
        }
      }
    }
  }

  private func refreshCover() {
    Task {
      do {
        try await ThumbnailCache.refreshThumbnail(id: book.id, type: .book)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.coverRefreshed"))
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markAsRead(bookId: String) {
    Task {
      do {
        try await BookService.shared.markAsRead(bookId: bookId)
        _ = try await SyncService.shared.syncBookAndSeries(bookId: bookId, seriesId: book.seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
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
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func downloadNotificationMessage(for status: DownloadStatus) -> String {
    switch status {
    case .downloaded:
      return String(localized: "notification.book.offlineRemoved", defaultValue: "Removed from offline")
    case .pending:
      return String(localized: "notification.book.downloadCancelled", defaultValue: "Download cancelled")
    case .notDownloaded, .failed:
      return String(localized: "notification.book.downloadQueued", defaultValue: "Download queued")
    }
  }

  @ViewBuilder
  private var detailsSection: some View {
    #if os(iOS)
      ControlGroup {
        if book.oneshot {
          NavigationLink(value: NavDestination.oneshotDetail(seriesId: book.seriesId)) {
            Label("Details", systemImage: "info.circle")
          }
        } else {
          NavigationLink(value: NavDestination.bookDetail(bookId: book.id)) {
            Label("Details", systemImage: "info.circle")
          }
        }

        if let onReadBook = onReadBook {
          Button {
            onReadBook(true)
          } label: {
            Label("Read Incognito", systemImage: "eye.slash")
          }
        }

        if showSeriesNavigation && !book.oneshot {
          NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
            Label("Series", systemImage: ContentIcon.series)
          }
        }
      }
    #else
      if let onReadBook = onReadBook {
        Button {
          onReadBook(true)
        } label: {
          Label("Read Incognito", systemImage: "eye.slash")
        }
        Divider()
      }
      if book.oneshot {
        NavigationLink(value: NavDestination.oneshotDetail(seriesId: book.seriesId)) {
          Label("Details", systemImage: "info.circle")
        }
      } else {
        NavigationLink(value: NavDestination.bookDetail(bookId: book.id)) {
          Label("Details", systemImage: "info.circle")
        }
      }
      if showSeriesNavigation && !book.oneshot {
        NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
          Label("Series", systemImage: ContentIcon.series)
        }
      }
      Divider()
    #endif
  }
}
