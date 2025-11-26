//
//  BookDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookDetailView: View {
  let bookId: String

  @Environment(\.dismiss) private var dismiss
  #if canImport(AppKit)
    @Environment(\.openWindow) private var openWindow
  #endif
  @State private var book: Book?
  @State private var isLoading = true
  @State private var readerState: BookReaderState?
  @State private var showDeleteConfirmation = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false
  @State private var bookReadLists: [ReadList] = []
  @State private var isLoadingRelations = false

  private var thumbnailURL: URL? {
    return BookService.shared.getBookThumbnailURL(id: bookId)
  }

  private var progress: Double {
    guard let book = book, let readProgress = book.readProgress else { return 0 }
    guard book.media.pagesCount > 0 else { return 0 }
    return Double(readProgress.page) / Double(book.media.pagesCount)
  }

  private var isCompleted: Bool {
    book?.readProgress?.completed ?? false
  }

  private var isInProgress: Bool {
    guard let readProgress = book?.readProgress else { return false }
    return !readProgress.completed
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let book = book {
          HStack(alignment: .top) {
            ThumbnailImage(url: thumbnailURL, width: 120)

            VStack(alignment: .leading) {
              Text(book.seriesTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Text(book.metadata.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

              HStack(spacing: 6) {
                InfoChip(
                  label: "\(book.metadata.number)",
                  systemImage: "number",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )
                InfoChip(
                  label: "\(book.media.pagesCount) pages",
                  systemImage: "book.pages",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
              }

              if book.deleted {
                InfoChip(
                  label: "Unavailable",
                  backgroundColor: Color.red.opacity(0.2),
                  foregroundColor: .red
                )
              }

              if let readProgress = book.readProgress {
                if isCompleted {
                  InfoChip(
                    label: "Completed",
                    systemImage: "checkmark.circle.fill",
                    backgroundColor: Color.green.opacity(0.2),
                    foregroundColor: .green
                  )
                } else {
                  InfoChip(
                    label: "Page \(readProgress.page) / \(book.media.pagesCount)",
                    systemImage: "circle.righthalf.filled",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                }
              } else {
                InfoChip(
                  label: "Unread",
                  systemImage: "circle",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )
              }

              if let releaseDate = book.metadata.releaseDate {
                InfoChip(
                  label: "Release: \(releaseDate)",
                  systemImage: "calendar",
                  backgroundColor: Color.orange.opacity(0.2),
                  foregroundColor: .orange
                )
              }

              // Authors as chips
              if let authors = book.metadata.authors, !authors.isEmpty {
                HStack(spacing: 6) {
                  ForEach(authors, id: \.name) { author in
                    InfoChip(
                      label: author.name,
                      systemImage: "person",
                      backgroundColor: Color.indigo.opacity(0.2),
                      foregroundColor: .indigo
                    )
                  }
                }
              }
            }

            Spacer()
          }

          BookActionsSection(
            book: book,
            onRead: { incognito in
              readerState = BookReaderState(book: book, incognito: incognito)
            }
          )

          if !isLoadingRelations && !bookReadLists.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                  .font(.caption)
                Text("Read Lists")
                  .font(.headline)
              }
              .foregroundColor(.secondary)

              VStack(alignment: .leading, spacing: 8) {
                ForEach(bookReadLists) { readList in
                  NavigationLink {
                    ReadListDetailView(readListId: readList.id)
                  } label: {
                    HStack {
                      Text(readList.name)
                        .foregroundColor(.primary)
                      Spacer()
                      Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                  }
                }
              }
            }
            .padding(.vertical, 8)
          }

          Divider()

          VStack(alignment: .leading, spacing: 12) {
            // Short info chips
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 6) {
                InfoChip(
                  label: book.media.mediaType.uppercased(),
                  systemImage: "doc.text",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
              }
              if let isbn = book.metadata.isbn, !isbn.isEmpty {
                InfoChip(
                  label: isbn,
                  systemImage: "barcode",
                  backgroundColor: Color.cyan.opacity(0.2),
                  foregroundColor: .cyan
                )
              }
            }

            InfoRow(
              label: "SIZE",
              value: book.size,
              icon: "internaldrive"
            )

            InfoRow(
              label: "FILE",
              value: book.url,
              icon: "document"
            )

            InfoRow(
              label: "CREATED",
              value: formatDate(book.created),
              icon: "calendar.badge.plus"
            )

            InfoRow(
              label: "LAST MODIFIED",
              value: formatDate(book.lastModified),
              icon: "calendar.badge.clock"
            )
          }

          if let summary = book.metadata.summary, !summary.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                  .font(.caption)
                Text("SUMMARY")
                  .font(.caption)
                  .fontWeight(.semibold)
              }
              .foregroundColor(.secondary)

              Text(summary)
                .font(.body)
                .foregroundColor(.primary)
            }
          }
        } else if isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Failed to load book details")
              .font(.headline)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding()
    }
    .navigationTitle("Book")
    #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    #if canImport(UIKit)
      .fullScreenCover(
        isPresented: isBookReaderPresented,
        onDismiss: {
          Task {
            await loadBook()
          }
        }
      ) {
        if let state = readerState, let book = state.book {
          BookReaderView(book: book, incognito: state.incognito)
        }
      }
    #else
      .onChange(of: readerState) { _, newState in
        if let state = newState, let book = state.book {
          ReaderWindowManager.shared.openReader(book: book, incognito: state.incognito)
          openWindow(id: "reader")
        } else {
          ReaderWindowManager.shared.closeReader()
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
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Menu {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          .disabled(!AppConfig.isAdmin)

          Divider()

          Button {
            analyzeBook()
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }
          .disabled(!AppConfig.isAdmin)

          Button {
            refreshMetadata()
          } label: {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
          }
          .disabled(!AppConfig.isAdmin)

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

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Book", systemImage: "trash")
          }
          .disabled(!AppConfig.isAdmin)

          Button(role: .destructive) {
            clearCache()
          } label: {
            Label("Clear Cache", systemImage: "xmark.circle")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookIds: [bookId],
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        },
        onComplete: {
          // Create already adds book, just refresh
          Task {
            await loadBook()
          }
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
          ErrorManager.shared.notify(message: "Book analysis started")
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
          ErrorManager.shared.notify(message: "Metadata refreshed")
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
        await ImageCache.clearDiskCache(forBookId: bookId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Book deleted")
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
        await MainActor.run {
          ErrorManager.shared.notify(message: "Marked as read")
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
          ErrorManager.shared.notify(message: "Marked as unread")
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
      await ImageCache.clearDiskCache(forBookId: bookId)
    }
  }

  @MainActor
  private func loadBook() async {
    isLoading = true
    do {
      let fetchedBook = try await BookService.shared.getBook(id: bookId)
      book = fetchedBook
      isLoading = false
      isLoadingRelations = true
      bookReadLists = []
      Task {
        await loadBookRelations(for: fetchedBook)
      }
    } catch {
      isLoading = false
      ErrorManager.shared.alert(error: error)
    }
  }

  @MainActor
  private func loadBookRelations(for book: Book) async {
    isLoadingRelations = true
    let targetBookId = book.id
    bookReadLists = []

    do {
      let readLists = try await BookService.shared.getReadListsForBook(bookId: book.id)
      if self.book?.id == targetBookId {
        withAnimation {
          bookReadLists = readLists
        }
      }
    } catch {
      if self.book?.id == targetBookId {
        bookReadLists = []
      }
      ErrorManager.shared.alert(error: error)
    }

    if self.book?.id == targetBookId {
      isLoadingRelations = false
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.shared.addBooksToReadList(
          readListId: readListId,
          bookIds: [bookId]
        )
        await MainActor.run {
          ErrorManager.shared.notify(message: "Books added to read list")
        }
        await loadBook()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
