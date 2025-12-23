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
  @Query var downloadedBooks: [KomgaBook]
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

  init() {
    let instanceId = AppConfig.currentInstanceId
    _downloadedBooks = Query(
      filter: #Predicate<KomgaBook> {
        $0.instanceId == instanceId && $0.downloadStatusRaw == "downloaded"
      },
      sort: [SortDescriptor(\KomgaBook.libraryId)]
    )
    _libraries = Query(
      filter: #Predicate<KomgaLibrary> {
        $0.instanceId == instanceId
      }
    )
  }

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
        let instanceId = AppConfig.currentInstanceId
        let compositeId = "\(instanceId)_\(seriesId)"
        let seriesDescriptor = FetchDescriptor<KomgaSeries>(
          predicate: #Predicate { $0.id == compositeId })
        let series = try? modelContext.fetch(seriesDescriptor).first

        sGroups.append(
          SeriesGroup(id: seriesId, series: series, books: sBooks.sorted { $0.number < $1.number }))
      }

      sGroups.sort {
        ($0.series?.name ?? $0.books.first?.seriesTitle ?? "")
          < ($1.series?.name ?? $1.books.first?.seriesTitle ?? "")
      }
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

  private var totalDownloadedSize: Int64 {
    downloadedBooks.reduce(0) { $0 + $1.downloadedSize }
  }

  var body: some View {
    Form {
      if downloadedBooks.isEmpty {
        ContentUnavailableView {
          Label(String(localized: "settings.offline.no_books"), systemImage: "books.vertical")
        } description: {
          Text(String(localized: "settings.offline.no_books.description"))
        }
      } else {
        Section {
          HStack {
            Text(String(localized: "settings.offline_books.total_size"))
              .fontWeight(.semibold)
            Spacer()
            Text(formatter.string(fromByteCount: totalDownloadedSize))
              .foregroundColor(.accentColor)
          }
        }

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
                    HStack {
                      Text("#\(book.metaNumber) - \(book.metaTitle)")
                        .font(.footnote)
                      Spacer()
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(sGroup.books) { book in
                    HStack {
                      Text("#\(book.metaNumber) - \(book.metaTitle)")
                        .font(.footnote)
                      Spacer()
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(book)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.controlSize(.small)
                    }
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
                  }.controlSize(.small)
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
                    HStack {
                      Text(book.metaTitle)
                        .font(.footnote)
                      Spacer()
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }
                }
              #else
                DisclosureGroup {
                  ForEach(lGroup.oneshotBooks) { book in
                    HStack {
                      Text(book.metaTitle)
                        .font(.footnote)
                      Spacer()
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(book)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.controlSize(.small)
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
                  }.controlSize(.small)
                }
              #endif
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.offlineBooks.title)
  }

  private func seriesSize(for books: [KomgaBook]) -> Int64 {
    books.reduce(0) { $0 + $1.downloadedSize }
  }

  private func totalSize(for lGroup: LibraryGroup) -> Int64 {
    let sSize = lGroup.seriesGroups.reduce(0) { $0 + seriesSize(for: $1.books) }
    let oSize = lGroup.oneshotBooks.reduce(0) { $0 + $1.downloadedSize }
    return sSize + oSize
  }

  private func deleteBook(_ book: KomgaBook) {
    Task {
      await OfflineManager.shared.deleteBookManually(
        seriesId: book.seriesId, instanceId: book.instanceId, bookId: book.bookId)
    }
  }

  private func deleteSeries(_ books: [KomgaBook]) {
    guard let firstBook = books.first else { return }
    Task {
      await OfflineManager.shared.deleteBooksManually(
        seriesId: firstBook.seriesId,
        instanceId: firstBook.instanceId,
        bookIds: books.map { $0.bookId }
      )
    }
  }
}
