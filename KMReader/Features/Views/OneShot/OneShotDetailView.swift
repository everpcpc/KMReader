//
//  OneshotDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftData
import SwiftUI

struct OneshotDetailView: View {
  let seriesId: String

  @Environment(\.dismiss) private var dismiss
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(\.readerZoomNamespace) private var zoomNamespace

  @Query private var komgaSeriesList: [KomgaSeries]
  @Query private var komgaBookList: [KomgaBook]

  @State private var isLoading = true
  @State private var isLoadingCollections = false
  @State private var isLoadingReadLists = false
  @State private var thumbnailRefreshTrigger = 0
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showCollectionPicker = false
  @State private var showReadListPicker = false
  @State private var containingCollections: [SeriesCollection] = []
  @State private var bookReadLists: [ReadList] = []

  init(seriesId: String) {
    self.seriesId = seriesId
    let instanceId = AppConfig.currentInstanceId
    let seriesCompositeId = "\(instanceId)_\(seriesId)"
    _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == seriesCompositeId })
    _komgaBookList = Query(
      filter: #Predicate<KomgaBook> { $0.instanceId == instanceId && $0.seriesId == seriesId })
  }

  /// The KomgaSeries from SwiftData (reactive).
  private var komgaSeries: KomgaSeries? {
    komgaSeriesList.first
  }

  /// The KomgaBook from SwiftData (reactive).
  private var komgaBook: KomgaBook? {
    komgaBookList.first
  }

  private var series: Series? {
    komgaSeries?.toSeries()
  }

  private var book: Book? {
    komgaBook?.toBook()
  }

  private var downloadStatus: DownloadStatus {
    komgaBook?.downloadStatus ?? .notDownloaded
  }

  private var progress: Double {
    guard let komgaBook = komgaBook else { return 0 }
    guard let readProgress = komgaBook.readProgress else { return 0 }
    guard komgaBook.mediaPagesCount > 0 else { return 0 }
    return Double(readProgress.page) / Double(komgaBook.mediaPagesCount)
  }

  private var isCompleted: Bool {
    komgaBook?.progressCompleted ?? false
  }

  private var isInProgress: Bool {
    guard let readProgress = komgaBook?.readProgress else { return false }
    return !readProgress.completed
  }

  private var hasReadInfo: Bool {
    guard let series else { return false }
    if let language = series.metadata.language, !language.isEmpty {
      return true
    }
    if let direction = series.metadata.readingDirection, !direction.isEmpty {
      return true
    }
    return false
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let book, let series {
          HStack(alignment: .bottom) {
            Text(book.metadata.title)
              .font(.title2)
              .fixedSize(horizontal: false, vertical: true)
            if let ageRating = series.metadata.ageRating, ageRating > 0 {
              AgeRatingBadge(ageRating: ageRating)
            }
            Spacer()
          }

          HStack(alignment: .top) {
            ThumbnailImage(
              id: book.id, type: .book,
              width: PlatformHelper.detailThumbnailWidth,
              refreshTrigger: thumbnailRefreshTrigger
            )
            .thumbnailFocus()
            .ifLet(zoomNamespace) { view, namespace in
              view.matchedTransitionSourceIfAvailable(id: book.id, in: namespace)
            }

            VStack(alignment: .leading) {
              HStack(spacing: 6) {
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

              if hasReadInfo {
                HStack(spacing: 6) {
                  if let language = series.metadata.language, !language.isEmpty {
                    InfoChip(
                      label: LanguageCodeHelper.displayName(for: language),
                      systemImage: "globe",
                      backgroundColor: Color.purple.opacity(0.2),
                      foregroundColor: .purple
                    )
                  }

                  if let direction = series.metadata.readingDirection, !direction.isEmpty {
                    InfoChip(
                      label: ReadingDirection.fromString(direction).displayName,
                      systemImage: ReadingDirection.fromString(direction).icon,
                      backgroundColor: Color.cyan.opacity(0.2),
                      foregroundColor: .cyan
                    )
                  }
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

              if let publisher = series.metadata.publisher, !publisher.isEmpty {
                InfoChip(
                  label: publisher,
                  systemImage: "building.2",
                  backgroundColor: Color.teal.opacity(0.2),
                  foregroundColor: .teal
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

          // Seires genres
          if let genres = series.metadata.genres, !genres.isEmpty {
            HFlow {
              ForEach(genres.sorted(), id: \.self) { genre in
                InfoChip(
                  label: genre,
                  systemImage: "bookmark",
                  backgroundColor: Color.blue.opacity(0.1),
                  foregroundColor: .blue,
                  cornerRadius: 8
                )
              }
            }
          }

          // Book tags
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
            seriesLink: false,
            onRead: { incognito in
              readerPresentation.present(book: book, incognito: incognito) {
                Task {
                  await refreshOneshotData()
                }
              }
            }
          )

          #if os(tvOS)
            oneshotToolbarContent
              .padding(.vertical, 8)
          #endif

          if !isLoadingCollections && !containingCollections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 4) {
                Text("Collections")
                  .font(.headline)
              }
              .foregroundColor(.secondary)

              VStack(alignment: .leading, spacing: 8) {
                ForEach(containingCollections) { collection in
                  NavigationLink(
                    value: NavDestination.collectionDetail(collectionId: collection.id)
                  ) {
                    HStack {
                      Label(collection.name, systemImage: "square.grid.2x2")
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
            .padding(.vertical)
          }

          if !isLoadingReadLists && !bookReadLists.isEmpty {
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
            .padding(.vertical)
          }

          if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Divider()
              Text("Alternate Titles")
                .font(.headline)
              VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(alternateTitles.enumerated()), id: \.offset) { index, altTitle in
                  HStack(alignment: .top, spacing: 4) {
                    Text("\(altTitle.label):")
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .frame(width: 60, alignment: .leading)
                    Text(altTitle.title)
                      .font(.caption)
                      .foregroundColor(.primary)
                  }
                }
              }
            }.padding(.bottom, 8)
          }

          if let links = book.metadata.links, !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Divider()
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
            }
          }

          // book media info
          VStack(alignment: .leading, spacing: 8) {
            Divider()
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
          }

          if let summary = book.metadata.summary, !summary.isEmpty {
            Divider()
            ExpandableSummaryView(summary: summary)
          }
        } else if isLoading {
          VStack(spacing: 16) {
            ProgressView()
          }
          .frame(maxWidth: .infinity)
        } else {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding()
    }
    .inlineNavigationBarTitle(String(localized: "Oneshot"))
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          oneshotToolbarContent
        }
      }
    #endif
    .alert("Delete Oneshot?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteOneshot()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(book?.metadata.title ?? "this oneshot") from Komga.")
    }
    .sheet(isPresented: $showCollectionPicker) {
      CollectionPickerSheet(
        seriesIds: [seriesId],
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        },
        onComplete: {
          Task {
            await refreshOneshotData()
          }
        }
      )
    }
    .sheet(isPresented: $showReadListPicker) {
      if let book = book {
        ReadListPickerSheet(
          bookIds: [book.id],
          onSelect: { readListId in
            addToReadList(readListId: readListId, bookId: book.id)
          },
          onComplete: {
            Task {
              await refreshOneshotData()
            }
          }
        )
      }
    }
    .sheet(isPresented: $showEditSheet) {
      if let series = series, let book = book {
        OneshotEditSheet(series: series, book: book)
          .onDisappear {
            Task {
              await refreshOneshotData()
            }
          }
      }
    }
    .task {
      await refreshOneshotData()
    }
  }

  private func refreshOneshotData() async {
    isLoading = true
    do {
      let previousLastModified = komgaSeries?.lastModified
      let fetchedSeries = try await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      if previousLastModified != fetchedSeries.lastModified {
        reloadThumbnail()
      }
      let fetchedBooks = try await SyncService.shared.syncBooks(
        seriesId: seriesId,
        page: 0,
        size: 1,
      )
      isLoading = false
      await loadOneshotCollections(seriesId: seriesId)
      if let fetchedBook = fetchedBooks.content.first {
        await loadBookReadLists(for: fetchedBook)
      }
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaSeries == nil || komgaBook == nil {
        ErrorManager.shared.alert(error: error)
      }
      isLoading = false
    }
  }

  private func loadOneshotCollections(seriesId: String) async {
    isLoadingCollections = true
    containingCollections = []
    do {
      let collections = try await SeriesService.shared.getSeriesCollections(seriesId: seriesId)
      withAnimation {
        containingCollections = collections
      }
    } catch {
      containingCollections = []
      ErrorManager.shared.alert(error: error)
    }
    isLoadingCollections = false
  }

  private func loadBookReadLists(for book: Book) async {
    isLoadingReadLists = true
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
      isLoadingReadLists = false
    }
  }

  private func reloadThumbnail() {
    guard !AppConfig.isOffline else { return }
    thumbnailRefreshTrigger += 1
  }

  private func clearCache() {
    guard let book = book else { return }
    Task {
      await CacheManager.clearCache(forBookId: book.id)
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        _ = try? await SyncService.shared.syncCollection(id: collectionId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.addedToCollection"))
        }
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markOneshotAsRead() {
    guard let book = book else { return }
    Task {
      do {
        try await BookService.shared.markAsRead(bookId: book.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
        }
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markOneshotAsUnread() {
    guard let book = book else { return }
    Task {
      do {
        try await BookService.shared.markAsUnread(bookId: book.id)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
        }
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteOneshot() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
          dismiss()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  private func addToReadList(readListId: String, bookId: String) {
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
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func analyzeOneshot() {
    guard let book = book else { return }
    Task {
      do {
        try await BookService.shared.analyzeBook(bookId: book.id)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.analysisStarted"))
        }
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func refreshMetadata() {
    guard let book = book else { return }
    Task {
      do {
        try await BookService.shared.refreshMetadata(bookId: book.id)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.book.metadataRefreshed"))
        }
        await refreshOneshotData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  @ViewBuilder
  private var oneshotToolbarContent: some View {
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
          analyzeOneshot()
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
          showCollectionPicker = true
        } label: {
          Label("Add to Collection", systemImage: "square.grid.2x2")
        }

        Button {
          showReadListPicker = true
        } label: {
          Label("Add to Read List", systemImage: "list.bullet")
        }

        Divider()

        if let book = book {
          if !(book.readProgress?.completed ?? false) {
            Button {
              markOneshotAsRead()
            } label: {
              Label("Mark as Read", systemImage: "checkmark.circle")
            }
          }

          if book.readProgress != nil {
            Button {
              markOneshotAsUnread()
            } label: {
              Label("Mark as Unread", systemImage: "circle")
            }
          }
        }

        Divider()

        Button(role: .destructive) {
          showDeleteConfirmation = true
        } label: {
          Label("Delete Oneshot", systemImage: "trash")
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
