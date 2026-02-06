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
  @AppStorage("currentAccount") private var current: Current = .init()

  @Query private var komgaSeriesList: [KomgaSeries]
  @Query private var komgaBookList: [KomgaBook]

  @State private var isLoading = true
  @State private var hasError = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showCollectionPicker = false
  @State private var showReadListPicker = false

  init(seriesId: String) {
    self.seriesId = seriesId
    let instanceId = AppConfig.current.instanceId
    let seriesCompositeId = CompositeID.generate(instanceId: instanceId, id: seriesId)
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

  private var navigationTitle: String {
    book?.metadata.title ?? String(localized: "Oneshot")
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading) {
        if let book, let series {
          #if os(tvOS)
            oneshotToolbarContent
              .padding(.vertical, 8)
          #endif

          OneShotDetailContentView(
            book: book,
            series: series,
            downloadStatus: downloadStatus,
            inSheet: false
          )

          if let komgaSeries = komgaSeries {
            SeriesCollectionsSection(collectionIds: komgaSeries.collectionIds)
          }

          if let komgaBook = komgaBook {
            BookReadListsSection(readListIds: komgaBook.readListIds)
          }
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
    .inlineNavigationBarTitle(navigationTitle)
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.oneshot(serverURL: current.serverURL, seriesId: seriesId),
      scope: .browse
    )
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
        seriesId: seriesId,
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
        }
      )
    }
    .sheet(isPresented: $showReadListPicker) {
      if let book = book {
        ReadListPickerSheet(
          bookId: book.id,
          onSelect: { readListId in
            addToReadList(readListId: readListId, bookId: book.id)
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
      _ = try await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      let fetchedBooks = try await SyncService.shared.syncBooks(
        seriesId: seriesId,
        page: 0,
        size: 1
      )
      isLoading = false
      await SyncService.shared.syncSeriesCollections(seriesId: seriesId)
      if let fetchedBook = fetchedBooks.content.first {
        await SyncService.shared.syncBookReadLists(bookId: fetchedBook.id)
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
        if current.isAdmin {
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
          Label("Add to Collection", systemImage: ContentIcon.collection)
        }

        Button {
          showReadListPicker = true
        } label: {
          Label("Add to Read List", systemImage: ContentIcon.readList)
        }

        Divider()

        if let book = book {
          if !(book.readProgress?.completed ?? false) {
            Button {
              markOneshotAsRead()
            } label: {
              Label("Mark as Read", systemImage: "checkmark")
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

        if current.isAdmin {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Oneshot", systemImage: "trash")
          }
        }

        if let book = book, book.isDivina {
          Button(role: .destructive) {
            clearCache()
          } label: {
            Label("Clear Cache", systemImage: "xmark")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
      .appMenuStyle()
      .toolbarButtonStyle()
    }
  }
}
