//
// BookQueryItemView.swift
//
//

import SwiftUI

/// Wrapper view that accepts only bookId and fetches a book display projection.
struct BookQueryItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true
  var readListContext: ReaderReadListContext? = nil

  @AppStorage("currentAccount") private var current: Current = .init()
  @Environment(\.readerActions) private var readerActions
  @State private var item: BookDisplayItem?
  @State private var projectionReloadTask: Task<Void, Never>?

  init(
    bookId: String,
    layout: BrowseLayoutMode,
    showSeriesTitle: Bool = true,
    showSeriesNavigation: Bool = true,
    readListContext: ReaderReadListContext? = nil
  ) {
    self.bookId = bookId
    self.layout = layout
    self.showSeriesTitle = showSeriesTitle
    self.showSeriesNavigation = showSeriesNavigation
    self.readListContext = readListContext

  }

  var body: some View {
    Group {
      if let item {
        switch layout {
        case .grid:
          BookCardView(
            item: item,
            onReadBook: { incognito in
              readerActions.open(
                book: item.book,
                incognito: incognito,
                readListContext: readListContext
              )
            },
            onMutationCompleted: reloadItem,
            showSeriesTitle: showSeriesTitle,
            showSeriesNavigation: showSeriesNavigation
          )
        case .list:
          BookRowView(
            item: item,
            onReadBook: { incognito in
              readerActions.open(
                book: item.book,
                incognito: incognito,
                readListContext: readListContext
              )
            },
            onMutationCompleted: reloadItem,
            showSeriesTitle: showSeriesTitle,
            showSeriesNavigation: showSeriesNavigation
          )
        }
      } else {
        CardPlaceholder(
          layout: layout,
          kind: .book,
          showBookSeriesTitle: showSeriesTitle
        )
      }
    }
    .task(id: "\(current.instanceId)|\(bookId)") {
      await loadItem()
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookProjectionDidChange)) {
      notification in
      guard shouldReload(for: notification) else { return }
      scheduleProjectionReload(after: ContentProjectionNotifier.refreshDelay(from: notification))
    }
    .onDisappear {
      cancelProjectionReload()
    }
  }

  private func shouldReload(for notification: Notification) -> Bool {
    if notification.userInfo?["bookId"] as? String == bookId {
      return true
    }
    if let bookIds = notification.userInfo?["bookIds"] as? Set<String> {
      return bookIds.contains(bookId)
    }
    if let bookIds = notification.userInfo?["bookIds"] as? [String] {
      return bookIds.contains(bookId)
    }
    return false
  }

  private func reloadItem() {
    Task {
      await loadItem()
    }
  }

  private func scheduleProjectionReload(
    after delay: UInt64 = ContentProjectionNotifier.localRefreshDelay
  ) {
    cancelProjectionReload()

    projectionReloadTask = Task { @MainActor in
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      await loadItem()
      projectionReloadTask = nil
    }
  }

  private func cancelProjectionReload() {
    projectionReloadTask?.cancel()
    projectionReloadTask = nil
  }

  private func loadItem() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchBookDisplayItem(
      bookId: bookId,
      instanceId: current.instanceId
    )
  }
}
