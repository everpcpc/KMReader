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
  @State private var book: Book?
  @State private var isLoading = true
  @State private var readerState: BookReaderState?
  @State private var showDeleteConfirmation = false
  @State private var showReadListPicker = false

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
              Text(book.metadata.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

              Text(book.seriesTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              HStack(spacing: 4) {
                Image(systemName: "book")
                  .font(.caption)
                Text("#\(book.metadata.number) · \(book.media.pagesCount) pages")
              }
              .font(.caption)
              .foregroundColor(.secondary)

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
                    systemImage: "book.pages",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                }
              } else {
                InfoChip(
                  label: "Unread",
                  systemImage: "circle"
                )
              }
            }

            Spacer()
          }

          BookActionsSection(
            book: book,
            onRead: { incognito in
              readerState = BookReaderState(bookId: book.id, incognito: incognito)
            }
          )

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
                if let releaseDate = book.metadata.releaseDate {
                  InfoChip(
                    label: releaseDate,
                    systemImage: "calendar",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                }
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

            if let authors = book.metadata.authors, !authors.isEmpty {
              InfoRow(
                label: "AUTHORS",
                value: authors.map { $0.name }.joined(separator: ", "),
                icon: "person"
              )
            }
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
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(
      isPresented: isBookReaderPresented,
      onDismiss: {
        Task {
          await loadBook()
        }
      }
    ) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
    .alert("Delete Book?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteBook()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(book?.metadata.title ?? "this book") from Komga.")
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
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
      book = try await BookService.shared.getBook(id: bookId)
      isLoading = false
    } catch {
      isLoading = false
      ErrorManager.shared.alert(error: error)
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
