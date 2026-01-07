//
//  BookDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftData
import SwiftUI

struct BookDetailView: View {
  let bookId: String

  @Environment(\.dismiss) private var dismiss
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Query private var komgaBooks: [KomgaBook]

  @State private var hasError = false
  @State private var showDeleteConfirmation = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false

  init(bookId: String) {
    self.bookId = bookId
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  /// The KomgaBook from SwiftData (reactive).
  private var komgaBook: KomgaBook? {
    komgaBooks.first
  }

  /// Convert to API Book type for compatibility with existing components.
  private var book: Book? {
    komgaBook?.toBook()
  }

  private var downloadStatus: DownloadStatus {
    komgaBook?.downloadStatus ?? .notDownloaded
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading) {
        if let book {
          #if os(tvOS)
            bookToolbarContent
              .padding(.vertical, 8)
          #endif

          BookDetailContentView(
            book: book,
            downloadStatus: downloadStatus
          )

          if let komgaBook = komgaBook {
            BookReadListsSection(readListIds: komgaBook.readListIds)
          }
        } else if hasError {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Failed to load book details")
              .font(.headline)
          }
          .frame(maxWidth: .infinity)
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding()
    }
    .inlineNavigationBarTitle(String(localized: "Book"))
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          bookToolbarContent
        }
      }
    #endif
    .alert("Delete Book?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteBook()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(book?.metadata.title ?? "this book") from Komga.")
    }
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookId: bookId,
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      if let book = book {
        BookEditSheet(book: book)
          .onDisappear {
            Task {
              await loadBook()
            }
          }
      }
    }
    .task {
      await loadBook()
    }
  }

  private func analyzeBook() {
    Task {
      do {
        try await BookService.shared.analyzeBook(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.analysisStarted"))
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func refreshMetadata() {
    Task {
      do {
        try await BookService.shared.refreshMetadata(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.metadataRefreshed"))
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteBook() {
    Task {
      do {
        try await BookService.shared.deleteBook(bookId: bookId)
        await CacheManager.clearCache(forBookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
          dismiss()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markBookAsRead() {
    Task {
      do {
        try await BookService.shared.markAsRead(bookId: bookId)
        if let book {
          _ = try? await SyncService.shared.syncBookAndSeries(
            bookId: bookId, seriesId: book.seriesId)
        }
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markBookAsUnread() {
    Task {
      do {
        try await BookService.shared.markAsUnread(bookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func clearCache() {
    Task {
      await CacheManager.clearCache(forBookId: bookId)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.book.cacheCleared"))
      }
    }
  }

  @MainActor
  private func loadBook() async {
    do {
      // Sync from network to SwiftData (book property will update reactively)
      _ = try await SyncService.shared.syncBook(bookId: bookId)
      await SyncService.shared.syncBookReadLists(bookId: bookId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else {
        if komgaBook == nil {
          hasError = true
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [bookId]
        )
        // Sync the readlist to update its bookIds in local SwiftData
        _ = try? await SyncService.shared.syncReadList(id: readListId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.booksAddedToReadList"))
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  @ViewBuilder
  private var bookToolbarContent: some View {
    HStack(spacing: PlatformHelper.buttonSpacing) {

      Menu {
        if isAdmin {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button {
            analyzeBook()
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }

          Button {
            refreshMetadata()
          } label: {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
          }
        }

        Divider()

        Button {
          showReadListPicker = true
        } label: {
          Label("Add to Read List", systemImage: "list.bullet")
        }

        Divider()

        if let book = book {
          if !(book.readProgress?.completed ?? false) {
            Button {
              markBookAsRead()
            } label: {
              Label("Mark as Read", systemImage: "checkmark.circle")
            }
          }

          if book.readProgress != nil {
            Button {
              markBookAsUnread()
            } label: {
              Label("Mark as Unread", systemImage: "circle")
            }
          }
        }

        Divider()

        if isAdmin {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Book", systemImage: "trash")
          }
        }

        Button(role: .destructive) {
          clearCache()
        } label: {
          Label("Clear Cache", systemImage: "xmark.circle")
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .toolbarButtonStyle()
    }
  }
}
