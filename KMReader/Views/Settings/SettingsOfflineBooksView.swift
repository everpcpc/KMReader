//
//  SettingsOfflineBooksView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsOfflineBooksView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(
    filter: #Predicate<KomgaBook> { $0.downloadStatusRaw == "downloaded" },
    sort: [SortDescriptor(\KomgaBook.libraryId)]
  )
  var downloadedBooks: [KomgaBook]

  @Query var libraries: [KomgaLibrary]

  struct SeriesGroup: Identifiable {
    let id: String
    let series: KomgaSeries?
    let books: [KomgaBook]
  }

  struct LibraryGroup: Identifiable {
    let id: String
    let library: KomgaLibrary?
    let seriesGroups: [SeriesGroup]
    let oneshotBooks: [KomgaBook]
  }

  private let formatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = .useAll
    f.countStyle = .file
    return f
  }()

  init() {}

  private var groupedBooks: [LibraryGroup] {
    let libraryGroups = Dictionary(grouping: downloadedBooks) { $0.libraryId }
    var result: [LibraryGroup] = []

    for (libraryId, lBooks) in libraryGroups {
      let library = libraries.first { $0.libraryId == libraryId }

      let oneshots = lBooks.filter { $0.oneshot }
      let seriesBooks = lBooks.filter { !$0.oneshot }

      let seriesGroupsMap = Dictionary(grouping: seriesBooks) { $0.seriesId }
      var sGroups: [SeriesGroup] = []

      for (seriesId, sBooks) in seriesGroupsMap {
        let series = sBooks.first?.series
        sGroups.append(
          SeriesGroup(id: seriesId, series: series, books: sBooks.sorted { $0.number < $1.number }))
      }

      sGroups.sort { ($0.series?.name ?? "") < ($1.series?.name ?? "") }
      result.append(
        LibraryGroup(
          id: libraryId,
          library: library,
          seriesGroups: sGroups,
          oneshotBooks: oneshots.sorted {
            ($0.metadata.title.isEmpty ? $0.name : $0.metadata.title)
              < ($1.metadata.title.isEmpty ? $1.name : $1.metadata.title)
          }
        ))
    }

    result.sort { ($0.library?.name ?? "") < ($1.library?.name ?? "") }
    return result
  }

  var body: some View {
    List {
      if downloadedBooks.isEmpty {
        ContentUnavailableView(
          String(localized: "settings.offline.no_books"),
          systemImage: "books.vertical",
          description: Text(String(localized: "settings.offline.no_books.description"))
        )
      } else {
        ForEach(groupedBooks) { lGroup in
          Section(
            header: HStack {
              Text(lGroup.library?.name ?? String(localized: "common.unknown"))
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
                    Text(sGroup.series?.name ?? String(localized: "common.unknown"))
                    Spacer()
                    Text(formatter.string(fromByteCount: seriesSize(for: sGroup.books)))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                ) {
                  ForEach(sGroup.books) { book in
                    bookRow(book)
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(sGroup.books) { book in
                    bookRow(book)
                  }
                } label: {
                  HStack {
                    Text(sGroup.series?.name ?? String(localized: "common.unknown"))
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
                  }
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
                  ForEach(lGroup.oneshotBooks) { book in
                    bookRow(book)
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(lGroup.oneshotBooks) { book in
                    bookRow(book)
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
                  }
                }
              #endif
            }
          }
        }
      }
    }
    .inlineNavigationBarTitle(String(localized: "settings.offline_books.title"))
  }

  @ViewBuilder
  private func bookRow(_ book: KomgaBook) -> some View {
    HStack {
      Text("#\(book.metadata.number) - \(book.metadata.title)")
      Spacer()
      if let size = book.downloadedSize {
        Text(formatter.string(fromByteCount: size))
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    #if !os(tvOS)
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        deleteBook(book)
      } label: {
        Label(String(localized: "Delete"), systemImage: "trash")
      }
    }
    #endif
  }

  private func seriesSize(for books: [KomgaBook]) -> Int64 {
    books.reduce(0) { $0 + ($1.downloadedSize ?? 0) }
  }

  private func totalSize(for lGroup: LibraryGroup) -> Int64 {
    let sSize = lGroup.seriesGroups.reduce(0) { $0 + seriesSize(for: $1.books) }
    let oSize = lGroup.oneshotBooks.reduce(0) { $0 + ($1.downloadedSize ?? 0) }
    return sSize + oSize
  }

  private func deleteBook(_ book: KomgaBook) {
    Task {
      await OfflineManager.shared.deleteBook(instanceId: book.instanceId, bookId: book.bookId)
    }
  }

  private func deleteSeries(_ books: [KomgaBook]) {
    Task {
      for book in books {
        await OfflineManager.shared.deleteBook(instanceId: book.instanceId, bookId: book.bookId)
      }
    }
  }
}
