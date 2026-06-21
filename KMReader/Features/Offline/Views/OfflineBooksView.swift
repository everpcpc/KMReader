//
// OfflineBooksView.swift
//
//

import SwiftUI

struct OfflineBooksView: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var showRemoveAllAlert = false
  @State private var showRemoveReadAlert = false
  @State private var isScanning = false
  @State private var snapshot: OfflineDownloadedBooksSnapshot = .empty
  @State private var progressTracker = DownloadProgressTracker.shared

  private let formatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = .useAll
    f.countStyle = .file
    return f
  }()

  var body: some View {
    Form {
      if snapshot.isEmpty {
        ContentUnavailableView {
          Label(String(localized: "settings.offline.no_books"), systemImage: ContentIcon.book)
        } description: {
          Text(String(localized: "settings.offline.no_books.description"))
        }
        .tvFocusableHighlight()
      } else {
        Section {
          HStack {
            Text(String(localized: "settings.offline_books.total"))
              .fontWeight(.semibold)
            countBadge(snapshot.totalDownloadedBooksCount)
            Spacer()
            totalMetrics(size: snapshot.totalDownloadedSize)
          }

          Button {
            Task {
              isScanning = true
              let result = await OfflineManager.shared.cleanupOrphanedFiles()
              isScanning = false
              if result.deletedCount > 0 {
                ErrorManager.shared.notify(
                  message: String(
                    localized:
                      "settings.offline_books.cleanup_orphaned.result \(result.deletedCount) \(formatter.string(fromByteCount: result.bytesFreed))"
                  )
                )
              } else {
                ErrorManager.shared.notify(
                  message: String(localized: "settings.offline_books.cleanup_orphaned.no_orphaned")
                )
              }
              await loadSnapshot()
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
            .disabled(!snapshot.hasUnprotectedReadBooks)
          }.adaptiveButtonStyle(.bordered)
        }

        ForEach(snapshot.libraryGroups) { lGroup in
          Section(
            header: HStack {
              Text(lGroup.name ?? String(localized: "Unknown"))
              countBadge(lGroup.downloadedBooksCount)
              Spacer()
              downloadedMetrics(size: lGroup.downloadedSize)
            }
          ) {
            ForEach(lGroup.seriesGroups) { sGroup in
              #if os(tvOS)
                Section(
                  header: HStack {
                    Text(sGroup.name ?? String(localized: "Unknown"))
                    countBadge(sGroup.downloadedBooksCount)
                    Spacer()
                    downloadedMetrics(size: sGroup.downloadedSize)
                  }
                ) {
                  ForEach(sGroup.books) { book in
                    HStack {
                      Text(book.listTitle)
                        .font(.footnote)

                      Spacer()
                      if book.isReadCompleted {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      protectionBadge(for: book)
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
                      Text(book.listTitle)
                        .font(.footnote)

                      Spacer()
                      if book.isReadCompleted {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      protectionBadge(for: book)
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(book)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.optimizedControlSize()
                    }
                  }
                } label: {
                  HStack {
                    Text(sGroup.name ?? String(localized: "Unknown"))
                    countBadge(sGroup.downloadedBooksCount)
                    Spacer()
                    downloadedMetrics(size: sGroup.downloadedSize)
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
                    countBadge(lGroup.oneshotBooks.count)
                    Spacer()
                    downloadedMetrics(size: downloadedSize(for: lGroup.oneshotBooks))
                  }
                ) {
                  ForEach(lGroup.oneshotBooks) { book in
                    HStack {
                      Text(book.oneshotTitle)
                        .font(.footnote)

                      Spacer()
                      if book.isReadCompleted {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      protectionBadge(for: book)
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
                      Text(book.oneshotTitle)
                        .font(.footnote)

                      Spacer()
                      if book.isReadCompleted {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.secondary)
                      }
                      protectionBadge(for: book)
                      Text(formatter.string(fromByteCount: book.downloadedSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                      Button(role: .destructive) {
                        deleteBook(book)
                      } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                      }.optimizedControlSize()
                    }
                  }
                } label: {
                  HStack {
                    Text(String(localized: "settings.offline_books.oneshots"))
                    countBadge(lGroup.oneshotBooks.count)
                    Spacer()
                    downloadedMetrics(size: downloadedSize(for: lGroup.oneshotBooks))
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
    .task(id: current.instanceId) {
      await loadSnapshot()
    }
    .onChange(of: progressTracker.queueUpdateToken) { _, _ in
      Task {
        await loadSnapshot()
      }
    }
  }

  private func downloadedSize(for books: [OfflineDownloadedBookItem]) -> Int64 {
    books.reduce(0) { $0 + $1.downloadedSize }
  }

  private func countBadge(_ count: Int) -> some View {
    Text(count, format: .number)
      .font(.caption2)
      .fontWeight(.semibold)
      .monospacedDigit()
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.secondary.opacity(0.12), in: Capsule())
      .foregroundColor(.secondary)
      .lineLimit(1)
  }

  private func totalMetrics(size: Int64) -> some View {
    Text(formatter.string(fromByteCount: size))
      .foregroundColor(.accentColor)
      .lineLimit(1)
  }

  private func downloadedMetrics(size: Int64) -> some View {
    Text(formatter.string(fromByteCount: size))
      .font(.caption)
      .foregroundColor(.secondary)
      .lineLimit(1)
  }

  @ViewBuilder
  private func protectionBadge(for book: OfflineDownloadedBookItem) -> some View {
    if !book.protectionSources.isEmpty {
      Menu {
        ForEach(book.protectionSources) { source in
          NavigationLink(value: protectionDestination(for: source)) {
            Label(source.displayName, systemImage: source.kind.systemImage)
          }
        }
      } label: {
        HStack(spacing: 3) {
          Image(systemName: "lock.fill")
          Text(protectionTitle(for: book.protectionSources))
        }
      }
      .font(.caption2)
      .foregroundColor(.accentColor)
      .lineLimit(1)
    }
  }

  private func protectionTitle(for sources: [OfflineProtectionSource]) -> String {
    sources.map(\.displayName).joined(separator: ", ")
  }

  private func protectionDestination(for source: OfflineProtectionSource) -> NavDestination {
    switch source.kind {
    case .series:
      return .seriesDetail(seriesId: source.sourceId)
    case .readList:
      return .readListDetail(readListId: source.sourceId)
    }
  }

  private func deleteBook(_ book: OfflineDownloadedBookItem) {
    Task {
      await OfflineManager.shared.deleteBookManually(
        instanceId: book.instanceId, bookId: book.bookId)
      await loadSnapshot()
    }
  }

  private func deleteSeries(_ books: [OfflineDownloadedBookItem]) {
    guard let firstBook = books.first else { return }
    Task {
      await OfflineManager.shared.deleteBooksManually(
        seriesIds: Set(books.map(\.seriesId)),
        instanceId: firstBook.instanceId,
        bookIds: books.map { $0.bookId }
      )
      await loadSnapshot()
    }
  }

  private func removeAllBooks() {
    Task {
      await OfflineManager.shared.deleteAllDownloadedBooks()
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.booksRemovedAll")
      )
      await loadSnapshot()
    }
  }

  private func removeReadBooks() {
    Task {
      await OfflineManager.shared.deleteReadBooks()
      ErrorManager.shared.notify(
        message: String(localized: "notification.offline.booksRemovedRead")
      )
      await loadSnapshot()
    }
  }

  private func loadSnapshot() async {
    let instanceId = current.instanceId
    guard !instanceId.isEmpty else {
      if snapshot != .empty {
        withAnimation {
          snapshot = .empty
        }
      }
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      let loadedSnapshot = try await database.fetchOfflineDownloadedBooksSnapshot(
        instanceId: instanceId
      )
      if snapshot != loadedSnapshot {
        withAnimation {
          snapshot = loadedSnapshot
        }
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
