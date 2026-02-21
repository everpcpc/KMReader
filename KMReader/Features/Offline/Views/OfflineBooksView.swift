//
// OfflineBooksView.swift
//
//

import SQLiteData
import SwiftUI

struct OfflineBooksView: View {
  @FetchAll private var books: [KomgaBookRecord]
  @FetchAll private var bookLocalStateList: [KomgaBookLocalStateRecord]
  @FetchAll private var libraries: [KomgaLibraryRecord]
  @FetchAll private var allSeries: [KomgaSeriesRecord]

  @State private var showRemoveAllAlert = false
  @State private var showRemoveReadAlert = false
  @State private var showCleanupAlert = false
  @State private var isScanning = false
  @State private var cleanupResult: (deletedCount: Int, bytesFreed: Int64)?

  struct OfflineBookItem: Identifiable {
    let book: KomgaBookRecord
    let localState: KomgaBookLocalStateRecord

    var id: String { book.bookId }
  }

  struct SeriesGroup: Identifiable {
    let id: String
    let series: KomgaSeriesRecord?
    let books: [OfflineBookItem]
  }

  struct LibraryGroup: Identifiable {
    let id: String
    let library: KomgaLibraryRecord?
    let seriesGroups: [SeriesGroup]
    let oneshotBooks: [OfflineBookItem]
  }

  private let formatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = .useAll
    f.countStyle = .file
    return f
  }()

  init() {
    let instanceId = AppConfig.current.instanceId
    _books = FetchAll(
      KomgaBookRecord.where { $0.instanceId.eq(instanceId) }.order(by: \.libraryId)
    )
    _bookLocalStateList = FetchAll(
      KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) }.order(by: \.bookId)
    )
    _libraries = FetchAll(
      KomgaLibraryRecord
        .where {
          $0.instanceId.eq(instanceId)
        }
    )
    _allSeries = FetchAll(
      KomgaSeriesRecord
        .where {
          $0.instanceId.eq(instanceId)
        }
    )
  }

  private var downloadedBookItems: [OfflineBookItem] {
    let bookIds = Set(books.map(\.bookId))
    let stateMap = Dictionary(
      bookLocalStateList
        .filter { bookIds.contains($0.bookId) }
        .map { ($0.bookId, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    return books.compactMap { book in
      let state = stateMap[book.bookId] ?? .empty(instanceId: book.instanceId, bookId: book.bookId)
      guard state.downloadStatusRaw == "downloaded" else { return nil }
      return OfflineBookItem(book: book, localState: state)
    }
  }

  private var groupedBooks: [LibraryGroup] {
    let libraryGroups = Dictionary(grouping: downloadedBookItems) { $0.book.libraryId }
    var result: [LibraryGroup] = []

    for (libraryId, lBooks) in libraryGroups {
      let library = libraries.first { $0.libraryId == libraryId }

      let oneshots = lBooks.filter { $0.book.oneshot }
      let seriesBooks = lBooks.filter { !$0.book.oneshot }

      let seriesGroupsMap = Dictionary(grouping: seriesBooks) { $0.book.seriesId }
      let seriesMap = Dictionary(
        allSeries.map { ($0.seriesId, $0) },
        uniquingKeysWith: { first, _ in first }
      )

      var sGroups: [SeriesGroup] = []
      for (seriesId, sBooks) in seriesGroupsMap {
        sGroups.append(
          SeriesGroup(
            id: seriesId, series: seriesMap[seriesId],
            books: sBooks.sorted { $0.book.metadata.numberSort < $1.book.metadata.numberSort }))
      }

      sGroups.sort {
        ($0.series?.name ?? $0.books.first?.book.seriesTitle ?? "")
          < ($1.series?.name ?? $1.books.first?.book.seriesTitle ?? "")
      }
      result.append(
        LibraryGroup(
          id: libraryId,
          library: library,
          seriesGroups: sGroups,
          oneshotBooks: oneshots.sorted {
            ($0.book.metadata.title.isEmpty ? $0.book.name : $0.book.metadata.title)
              < ($1.book.metadata.title.isEmpty ? $1.book.name : $1.book.metadata.title)
          }
        ))
    }

    result.sort { ($0.library?.name ?? "") < ($1.library?.name ?? "") }
    return result
  }

  private var totalDownloadedSize: Int64 {
    downloadedBookItems.reduce(0) { $0 + $1.localState.downloadedSize }
  }

  private var hasReadBooks: Bool {
    downloadedBookItems.contains { $0.book.readProgress?.completed == true }
  }

  var body: some View {
    Form {
      if downloadedBookItems.isEmpty {
        ContentUnavailableView {
          Label(String(localized: "settings.offline.no_books"), systemImage: ContentIcon.book)
        } description: {
          Text(String(localized: "settings.offline.no_books.description"))
        }
        .tvFocusableHighlight()
      } else {
        Section {
          HStack {
            Text(String(localized: "settings.offline_books.total_size"))
              .fontWeight(.semibold)
            Spacer()
            Text(formatter.string(fromByteCount: totalDownloadedSize))
              .foregroundColor(.accentColor)
          }

          Button {
            Task {
              isScanning = true
              let result = await OfflineManager.shared.cleanupOrphanedFiles()
              cleanupResult = result
              isScanning = false
              showCleanupAlert = true
            }
          } label: {
            HStack {
              Label(
                String(localized: "settings.offline_books.cleanup_orphaned"),
                systemImage: "arrow.3.trianglepath"
              )
              Spacer()
              if isScanning {
                ProgressView()
              }
            }
          }
          .disabled(isScanning)
        } header: {
          HStack {
            Button(role: .destructive) {
              showRemoveAllAlert = true
            } label: {
              Label(String(localized: "settings.offline_books.remove_all"), systemImage: "trash")
            }
            Spacer()
            Button(role: .destructive) {
              showRemoveReadAlert = true
            } label: {
              Label(
                String(localized: "settings.offline_books.remove_read"),
                systemImage: "checkmark.circle")
            }
            .disabled(!hasReadBooks)
          }.adaptiveButtonStyle(.bordered)
        }

        ForEach(groupedBooks) { lGroup in
          Section(
            header: HStack {
              Text(lGroup.library?.name ?? String(localized: "Unknown"))
              Spacer()
              Text(formatter.string(fromByteCount: totalSize(for: lGroup)))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          ) {
            ForEach(lGroup.seriesGroups) { sGroup in
              #if os(tvOS)
                Section(
                  header: HStack {
                    Text(sGroup.series?.name ?? String(localized: "Unknown"))
                    Spacer()
                    Text(formatter.string(fromByteCount: seriesSize(for: sGroup.books)))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                ) {
                  ForEach(sGroup.books) { item in
                    let book = item.book
                    HStack {
                      Text("#\(book.metaNumber) - \(book.metaTitle)")
                        .font(.footnote)

                      Spacer()
                      if book.readProgress?.completed == true {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      Text(formatter.string(fromByteCount: item.localState.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(sGroup.books) { item in
                    let book = item.book
                    HStack {
                      Text("#\(book.metaNumber) - \(book.metaTitle)")
                        .font(.footnote)

                      Spacer()
                      if book.readProgress?.completed == true {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      Text(formatter.string(fromByteCount: item.localState.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(item)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.optimizedControlSize()
                    }
                  }
                } label: {
                  HStack {
                    Text(sGroup.series?.name ?? String(localized: "Unknown"))
                    Spacer()
                    Text(formatter.string(fromByteCount: seriesSize(for: sGroup.books)))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) {
                    deleteSeries(sGroup.books)
                  } label: {
                    Label(String(localized: "Delete All"), systemImage: "trash")
                  }.optimizedControlSize()
                }
              #endif
            }

            if !lGroup.oneshotBooks.isEmpty {
              #if os(tvOS)
                Section(
                  header: HStack {
                    Text(String(localized: "settings.offline_books.oneshots"))
                    Spacer()
                    Text(formatter.string(fromByteCount: seriesSize(for: lGroup.oneshotBooks)))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                ) {
                  ForEach(lGroup.oneshotBooks) { item in
                    let book = item.book
                    HStack {
                      Text(book.metaTitle)
                        .font(.footnote)

                      Spacer()
                      if book.readProgress?.completed == true {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      Text(formatter.string(fromByteCount: item.localState.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(lGroup.oneshotBooks) { item in
                    let book = item.book
                    HStack {
                      Text(book.metaTitle)
                        .font(.footnote)

                      Spacer()
                      if book.readProgress?.completed == true {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      Spacer()
                      Text(formatter.string(fromByteCount: item.localState.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(item)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.optimizedControlSize()
                    }
                  }
                } label: {
                  HStack {
                    Text(String(localized: "settings.offline_books.oneshots"))
                    Spacer()
                    Text(formatter.string(fromByteCount: seriesSize(for: lGroup.oneshotBooks)))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) {
                    deleteSeries(lGroup.oneshotBooks)
                  } label: {
                    Label(String(localized: "Delete All"), systemImage: "trash")
                  }.optimizedControlSize()
                }
              #endif
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(OfflineSection.books.title)
    .alert(
      String(localized: "settings.offline_books.remove_all"),
      isPresented: $showRemoveAllAlert
    ) {
      Button(String(localized: "Cancel"), role: .cancel) {}
      Button(String(localized: "Delete"), role: .destructive) {
        removeAllBooks()
      }
    } message: {
      Text(String(localized: "settings.offline_books.remove_all.message"))
    }
    .alert(
      String(localized: "settings.offline_books.remove_read"),
      isPresented: $showRemoveReadAlert
    ) {
      Button(String(localized: "Cancel"), role: .cancel) {}
      Button(String(localized: "Delete"), role: .destructive) {
        removeReadBooks()
      }
    } message: {
      Text(String(localized: "settings.offline_books.remove_read.message"))
    }
    .alert(
      String(localized: "settings.offline_books.cleanup_orphaned"),
      isPresented: $showCleanupAlert
    ) {
      Button(String(localized: "OK")) {}
    } message: {
      if let result = cleanupResult {
        if result.deletedCount > 0 {
          Text(
            String(
              localized:
                "settings.offline_books.cleanup_orphaned.result \(result.deletedCount) \(formatter.string(fromByteCount: result.bytesFreed))"
            ))
        } else {
          Text(String(localized: "settings.offline_books.cleanup_orphaned.no_orphaned"))
        }
      }
    }
  }

  private func seriesSize(for books: [OfflineBookItem]) -> Int64 {
    books.reduce(0) { $0 + $1.localState.downloadedSize }
  }

  private func totalSize(for lGroup: LibraryGroup) -> Int64 {
    let sSize = lGroup.seriesGroups.reduce(0) { $0 + seriesSize(for: $1.books) }
    let oSize = lGroup.oneshotBooks.reduce(0) { $0 + $1.localState.downloadedSize }
    return sSize + oSize
  }

  private func deleteBook(_ item: OfflineBookItem) {
    let book = item.book
    Task {
      await OfflineManager.shared.deleteBookManually(
        seriesId: book.seriesId, instanceId: book.instanceId, bookId: book.bookId)
    }
  }

  private func deleteSeries(_ books: [OfflineBookItem]) {
    guard let firstBook = books.first?.book else { return }
    Task {
      await OfflineManager.shared.deleteBooksManually(
        seriesId: firstBook.seriesId,
        instanceId: firstBook.instanceId,
        bookIds: books.map { $0.book.bookId }
      )
    }
  }

  private func removeAllBooks() {
    Task {
      await OfflineManager.shared.deleteAllDownloadedBooks()
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.booksRemovedAll")
      )
    }
  }

  private func removeReadBooks() {
    Task {
      await OfflineManager.shared.deleteReadBooks()
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.booksRemovedRead")
      )
    }
  }
}
