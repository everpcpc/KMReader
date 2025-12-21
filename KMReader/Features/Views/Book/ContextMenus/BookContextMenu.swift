//
//  BookContextMenu.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

@MainActor
struct BookContextMenu: View {
  @Environment(KomgaBook.self) private var komgaBook

  let viewModel: BookViewModel
  var onReadBook: ((Bool) -> Void)?
  var onActionCompleted: (() -> Void)? = nil
  var onShowReadListPicker: (() -> Void)? = nil
  var onDeleteRequested: (() -> Void)? = nil
  var onEditRequested: (() -> Void)? = nil
  var showSeriesNavigation: Bool = true

  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

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
      if let onReadBook = onReadBook {
        Button {
          onReadBook(true)
        } label: {
          Label("Read Incognito", systemImage: "eye.slash")
        }
      }

      Divider()

      NavigationLink(value: NavDestination.bookDetail(bookId: book.id)) {
        Label("View Details", systemImage: "info.circle")
      }
      if showSeriesNavigation {
        NavigationLink(value: NavDestination.seriesDetail(seriesId: book.seriesId)) {
          Label("Go to Series", systemImage: "book.fill")
        }
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
      .tint(downloadStatus.menuColor)

      Divider()

      Menu {
        Button {
          onEditRequested?()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .disabled(!isAdmin)

        Divider()

        Button {
          analyzeBook(bookId: book.id)
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(!isAdmin)

        Button {
          refreshMetadata(bookId: book.id)
        } label: {
          Label("Refresh Metadata", systemImage: "arrow.clockwise")
        }
        .disabled(!isAdmin)

        Divider()

        Button {
          onShowReadListPicker?()
        } label: {
          Label("Add to Read List", systemImage: "list.bullet")
        }

        Divider()

        Button(role: .destructive) {
          onDeleteRequested?()
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .disabled(!isAdmin)
      } label: {
        Label("Manage", systemImage: "gearshape")
      }
      .disabled(!isAdmin)

      Divider()

      if !isCompleted {
        Button {
          Task {
            await viewModel.markAsRead(bookId: book.id)
            await MainActor.run {
              onActionCompleted?()
            }
          }
        } label: {
          Label("Mark as Read", systemImage: "checkmark.circle")
        }
      }
      if book.readProgress != nil {
        Button {
          Task {
            await viewModel.markAsUnread(bookId: book.id)
            await MainActor.run {
              onActionCompleted?()
            }
          }
        } label: {
          Label("Mark as Unread", systemImage: "circle")
        }
      }

      Divider()

      Button(role: .destructive) {
        Task {
          await CacheManager.clearCache(forBookId: book.id)
        }
      } label: {
        Label("Clear Cache", systemImage: "xmark.circle")
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
