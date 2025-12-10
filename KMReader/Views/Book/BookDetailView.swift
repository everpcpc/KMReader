//
//  BookDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct BookDetailView: View {
  let bookId: String

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @State private var book: Book?
  @State private var isLoading = true
  @State private var showDeleteConfirmation = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false
  @State private var bookReadLists: [ReadList] = []
  @State private var isLoadingRelations = false
  @State private var showDownloadSheet = false

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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let book = book {
          Text(book.seriesTitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          Text(book.metadata.title)
            .font(.title2)
            .fixedSize(horizontal: false, vertical: true)

          HStack(alignment: .top) {
            ThumbnailImage(url: thumbnailURL, width: PlatformHelper.detailThumbnailWidth)
              .thumbnailFocus()

            VStack(alignment: .leading) {
              HStack(spacing: 6) {
                InfoChip(
                  label: "\(book.metadata.number)",
                  systemImage: "number",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )
                InfoChip(
                  labelKey: "\(book.media.pagesCount) pages",
                  systemImage: "book.pages",
                  backgroundColor: Color.blue.opacity(0.2),
                  foregroundColor: .blue
                )
              }

              if book.deleted {
                InfoChip(
                  labelKey: "Unavailable",
                  backgroundColor: Color.red.opacity(0.2),
                  foregroundColor: .red
                )
              }

              if let readProgress = book.readProgress {
                if isCompleted {
                  InfoChip(
                    labelKey: "Completed",
                    systemImage: "checkmark.circle.fill",
                    backgroundColor: Color.green.opacity(0.2),
                    foregroundColor: .green
                  )
                } else {
                  InfoChip(
                    labelKey: "Page \(readProgress.page) / \(book.media.pagesCount)",
                    systemImage: "circle.righthalf.filled",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
                }
              } else {
                InfoChip(
                  labelKey: "Unread",
                  systemImage: "circle",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )
              }

              if let releaseDate = book.metadata.releaseDate {
                InfoChip(
                  label: releaseDate,
                  systemImage: "calendar",
                  backgroundColor: Color.orange.opacity(0.2),
                  foregroundColor: .orange
                )
              }

              // Authors as chips
              if let authors = book.metadata.authors, !authors.isEmpty {
                HFlow {
                  ForEach(authors, id: \.self) { author in
                    InfoChip(
                      label: author.name,
                      systemImage: author.roleIcon,
                      backgroundColor: Color.indigo.opacity(0.2),
                      foregroundColor: .indigo
                    )
                  }
                }
              }
            }
          }

          // Created and last modified dates
          HStack(spacing: 6) {
            InfoChip(
              labelKey: "Created: \(formatDate(book.created))",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              labelKey: "Modified: \(formatDate(book.lastModified))",
              systemImage: "clock",
              backgroundColor: Color.purple.opacity(0.2),
              foregroundColor: .purple
            )
          }

          Divider()
          BookActionsSection(
            book: book,
            onRead: { incognito in
              readerPresentation.present(book: book, incognito: incognito) {
                Task {
                  await loadBook()
                }
              }
            }
          )
          Divider()

          #if os(tvOS)
            bookToolbarContent
              .padding(.vertical, 8)
          #endif

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
                      Label(readList.name, systemImage: "list.bullet")
                        .foregroundColor(.primary)
                      Spacer()
                      Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(16)
                  }
                }
              }
            }
            .padding(.vertical, 8)
          }

          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
              InfoChip(
                label: book.media.mediaType.uppercased(),
                systemImage: "doc.text",
                backgroundColor: Color.blue.opacity(0.2),
                foregroundColor: .blue
              )
              InfoChip(
                label: book.size,
                systemImage: "internaldrive",
                backgroundColor: Color.teal.opacity(0.2),
                foregroundColor: .teal
              )
            }
            InfoChip(
              label: book.url,
              systemImage: "document",
              backgroundColor: Color.gray.opacity(0.2),
              foregroundColor: .gray
            )
            if let isbn = book.metadata.isbn, !isbn.isEmpty {
              InfoChip(
                label: isbn,
                systemImage: "barcode",
                backgroundColor: Color.cyan.opacity(0.2),
                foregroundColor: .cyan
              )
            }
          }

          if let summary = book.metadata.summary, !summary.isEmpty {
            Divider()
            ExpandableSummaryView(summary: summary)
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
    .inlineNavigationBarTitle(String(localized: "title.book"))
    .alert("Delete Book?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteBook()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(book?.metadata.title ?? "this book") from Komga.")
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          bookToolbarContent
        }
      }
    #endif
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
    .sheet(isPresented: $showDownloadSheet) {
      if let book = book {
        BookDownloadSheet(book: book)
      } else {
        ProgressView()
          .platformSheetPresentation(detents: [.medium])
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
        await CacheManager.clearCache(forBookId: bookId)
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
      await CacheManager.clearCache(forBookId: bookId)
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
    formatter.timeStyle = .none
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

  @ViewBuilder
  private var bookToolbarContent: some View {
    Menu {
      Button {
        showEditSheet = true
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      .disabled(!isAdmin)

      Divider()

      Button {
        analyzeBook()
      } label: {
        Label("Analyze", systemImage: "waveform.path.ecg")
      }
      .disabled(!isAdmin)

      Button {
        refreshMetadata()
      } label: {
        Label("Refresh Metadata", systemImage: "arrow.clockwise")
      }
      .disabled(!isAdmin)

      Divider()

      Button {
        showDownloadSheet = true
      } label: {
        Label("Download", systemImage: "arrow.down.circle")
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

      Button(role: .destructive) {
        showDeleteConfirmation = true
      } label: {
        Label("Delete Book", systemImage: "trash")
      }
      .disabled(!isAdmin)

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
