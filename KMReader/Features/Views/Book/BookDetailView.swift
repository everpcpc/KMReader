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
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(\.readerZoomNamespace) private var zoomNamespace
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  // SwiftData query for reactive download status
  @Query private var komgaBooks: [KomgaBook]

  @State private var isLoading = true
  @State private var showDeleteConfirmation = false
  @State private var showReadListPicker = false
  @State private var showEditSheet = false
  @State private var bookReadLists: [ReadList] = []
  @State private var isLoadingRelations = false
  @State private var showDownloadSheet = false
  @State private var thumbnailRefreshTrigger = 0

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

  /// Download status from SwiftData (reactive, no manual refresh needed).
  private var downloadStatus: DownloadStatus {
    komgaBook?.downloadStatus ?? .notDownloaded
  }

  /// Convert to API Book type for compatibility with existing components.
  private var book: Book? {
    komgaBook?.toBook()
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
            ThumbnailImage(
              id: bookId, type: .book, width: PlatformHelper.detailThumbnailWidth,
              refreshTrigger: thumbnailRefreshTrigger
            )
            .thumbnailFocus()
            .ifLet(zoomNamespace) { view, namespace in
              view.matchedTransitionSourceIfAvailable(id: bookId, in: namespace)
            }

            VStack(alignment: .leading) {
              HStack(spacing: 6) {
                InfoChip(
                  label: "\(book.metadata.number)",
                  systemImage: "number",
                  backgroundColor: Color.gray.opacity(0.2),
                  foregroundColor: .gray
                )

                if book.media.status != .ready {
                  InfoChip(
                    label: book.media.status.label,
                    systemImage: book.media.status.icon,
                    backgroundColor: book.media.status.color.opacity(0.2),
                    foregroundColor: book.media.status.color
                  )
                } else {
                  InfoChip(
                    labelKey: "\(book.media.pagesCount) pages",
                    systemImage: "book.pages",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                }
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

                InfoChip(
                  labelKey: "Last Read: \(formatDate(readProgress.readDate))",
                  systemImage: "book.closed",
                  backgroundColor: Color.teal.opacity(0.2),
                  foregroundColor: .teal
                )
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
                  labelKey: "Release Date: \(releaseDate)",
                  systemImage: "calendar",
                  backgroundColor: Color.orange.opacity(0.2),
                  foregroundColor: .orange
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

              // Authors as chips
              if let authors = book.metadata.authors, !authors.isEmpty {
                HFlow {
                  ForEach(authors.sortedByRole(), id: \.self) { author in
                    InfoChip(
                      label: author.name,
                      systemImage: author.role.icon,
                      backgroundColor: Color.indigo.opacity(0.2),
                      foregroundColor: .indigo
                    )
                  }
                }
              }
            }
          }

          // Tags
          if let tags = book.metadata.tags, !tags.isEmpty {
            HFlow {
              ForEach(tags.sorted(), id: \.self) { tag in
                InfoChip(
                  label: tag,
                  systemImage: "tag",
                  backgroundColor: Color.secondary.opacity(0.1),
                  foregroundColor: .secondary,
                  cornerRadius: 8
                )
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

          if let komgaBook = komgaBook {
            Divider()
            BookDownloadActionsSection(komgaBook: komgaBook)
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
                  NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
                    HStack {
                      Label(readList.name, systemImage: "list.bullet")
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

          // book media info
          VStack(alignment: .leading, spacing: 8) {
            Text("Media Information")
              .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Image(systemName: "doc.text.magnifyingglass")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(minWidth: 16)
                Text(book.media.mediaType.uppercased())
                  .font(.caption)
                Spacer()
              }

              HStack {
                Image(systemName: "internaldrive")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(minWidth: 16)
                Text(book.size)
                  .font(.caption)
                Spacer()
              }

              HStack(alignment: .top) {
                Image(systemName: "folder")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(minWidth: 16)
                Text(book.url)
                  .font(.caption)
                Spacer()
              }

              if let comment = book.media.comment, !comment.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                  Image("exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                  Text(comment)
                    .font(.caption)
                    .foregroundColor(.red)
                }
              }
            }
            Divider()
          }

          // Links
          if let links = book.metadata.links, !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Links")
                .font(.headline)
              HFlow {
                ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                  if let url = URL(string: link.url) {
                    Link(destination: url) {
                      InfoChip(
                        label: link.label,
                        systemImage: "link",
                        backgroundColor: Color.blue.opacity(0.2),
                        foregroundColor: .blue
                      )
                    }
                  } else {
                    InfoChip(
                      label: link.label,
                      systemImage: "link",
                      backgroundColor: Color.gray.opacity(0.2),
                      foregroundColor: .gray
                    )
                  }
                }
              }
              Divider()
            }
          }

          if let summary = book.metadata.summary, !summary.isEmpty {
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
    }
  }

  private func reloadThumbnail() {
    guard !AppConfig.isOffline else { return }
    thumbnailRefreshTrigger += 1
  }

  @MainActor
  private func loadBook() async {
    // Only show loading if we don't have cached data
    isLoading = komgaBook == nil

    do {
      // Sync from network to SwiftData (book property will update reactively)
      let previousLastModified = komgaBook?.lastModified
      let fetchedBook = try await SyncService.shared.syncBook(bookId: bookId)
      isLoading = false
      isLoadingRelations = true
      bookReadLists = []
      Task {
        await loadBookRelations(for: fetchedBook)
      }
      if previousLastModified != fetchedBook.lastModified {
        reloadThumbnail()
      }
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else {
        isLoading = false
        if komgaBook == nil {
          ErrorManager.shared.alert(error: error)
        }
      }
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

        // Note: Removed "Show Download Sheet" as we have a direct button now.

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
}
