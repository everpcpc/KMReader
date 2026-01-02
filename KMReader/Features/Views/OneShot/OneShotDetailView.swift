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

  @Query private var komgaSeriesList: [KomgaSeries]
  @Query private var komgaBookList: [KomgaBook]

  @State private var isLoading = true
  @State private var hasError = false
  @State private var isLoadingCollections = false
  @State private var isLoadingReadLists = false
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let book, let series {
          #if os(tvOS)
            oneshotToolbarContent
              .padding(.vertical, 8)
          #endif

          OneShotDetailContentView(
            book: book,
            series: series,
            downloadStatus: downloadStatus,
            containingCollections: containingCollections,
            bookReadLists: bookReadLists
          )
        } else if hasError {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
        } else {
          VStack(spacing: 16) {
            ProgressView()
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
      let fetchedSeries = try await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      let fetchedBooks = try await SyncService.shared.syncBooks(
        seriesId: fetchedSeries.id,
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
        hasError = true
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

  private func clearCache() {
    guard let book = book else { return }
    Task {
      await CacheManager.clearCache(forBookId: book.id)
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.book.cacheCleared"))
      }
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
        _ = try? await SyncService.shared.syncBookAndSeries(bookId: book.id, seriesId: seriesId)
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
        if isAdmin {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button {
            analyzeOneshot()
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

        if isAdmin {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Oneshot", systemImage: "trash")
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
