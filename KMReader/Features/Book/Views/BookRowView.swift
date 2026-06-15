//
// BookRowView.swift
//
//

import SwiftUI

struct BookRowView: View {
  let item: BookDisplayItem
  var onReadBook: ((Bool) -> Void)?
  var onMutationCompleted: (() -> Void)? = nil
  var showSeriesTitle: Bool = false
  var showSeriesNavigation: Bool = true

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

  @State private var showReadListPicker = false
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false

  private var progress: Double {
    guard let progressPage = item.progressPage else { return 0 }
    guard item.mediaPagesCount > 0 else { return 0 }
    return Double(progressPage) / Double(item.mediaPagesCount)
  }

  var shouldShowSeriesTitle: Bool {
    return showSeriesTitle && !item.seriesTitle.isEmpty
  }

  var bookTitleLine: String {
    if item.oneshot {
      return item.metaTitle
    }
    return String("\(item.metaNumber) - \(item.metaTitle)")
  }

  var bookTitleLineLimit: Int {
    (shouldShowSeriesTitle || item.oneshot) ? 1 : 2
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && item.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        onReadBook?(false)
      } label: {
        ThumbnailImage(
          id: item.bookId,
          type: .book,
          contentBlurRadius: coverBlurRadius,
          width: 60
        )
      }.adaptiveButtonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Button {
          onReadBook?(false)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            if item.oneshot {
              Text("Oneshot")
                .font(.footnote)
                .foregroundColor(.blue)
            } else if shouldShowSeriesTitle {
              Text(item.seriesTitle)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Text("#\(item.metaNumber) - \(item.metaTitle)")
              .foregroundColor(item.isCompleted ? .secondary : .primary)
              .lineLimit(bookTitleLineLimit)
          }
        }.adaptiveButtonStyle(.plain)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
              if let releaseDate = item.metaReleaseDate, !releaseDate.isEmpty {
                Label(releaseDate, systemImage: "calendar")
              } else {
                Label(
                  item.created.formatted(date: .abbreviated, time: .omitted),
                  systemImage: "clock")
              }
              if let progressPage = item.progressPage,
                let progressCompleted = item.progressCompleted
              {
                Text("•")
                if progressCompleted {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                  if let completedLastReadText = item.completedLastReadText {
                    Text(completedLastReadText)
                  }
                } else {
                  Image(systemName: "circle.righthalf.filled")
                    .foregroundColor(.blue)
                  Text("Page \(progressPage + 1)")
                    .foregroundColor(.blue)
                  Text("•")
                  Text(progress, format: .percent.precision(.fractionLength(0)))
                }
              }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
              let mediaStatus = item.media.statusValue
              if item.isUnavailable {
                Text("Unavailable")
                  .foregroundColor(.red)
              } else if mediaStatus != .ready {
                Text(mediaStatus.label)
                  .foregroundColor(mediaStatus.color)
              } else {
                Label("\(item.mediaPagesCount) pages", systemImage: "book.pages")
                  .foregroundColor(.secondary)
                Text("•").foregroundColor(.secondary)
                Label(item.size, systemImage: "doc")
                  .foregroundColor(.secondary)
              }
            }.font(.footnote)
          }

          Spacer()

          if item.downloadStatus != .notDownloaded {
            Image(systemName: item.downloadStatus.displayIcon)
              .foregroundColor(item.downloadStatus.displayColor)
          }
          EllipsisMenuButton {
            BookContextMenu(
              book: item.book,
              downloadStatus: item.downloadStatus,
              onReadBook: onReadBook,
              onShowReadListPicker: {
                showReadListPicker = true
              },
              onDeleteRequested: {
                showDeleteConfirmation = true
              },
              onEditRequested: {
                showEditSheet = true
              },
              onMutationCompleted: onMutationCompleted,
              showSeriesNavigation: showSeriesNavigation
            )
            .id(item.bookId)
          }
        }
      }
    }
    .alert("Delete Book", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deleteBook()
      }
    } message: {
      Text("Are you sure you want to delete this book? This action cannot be undone.")
    }
    .sheet(isPresented: $showReadListPicker) {
      ReadListPickerSheet(
        bookId: item.bookId,
        onSelect: { readListId in
          addToReadList(readListId: readListId)
        }
      )
    }
    .sheet(isPresented: $showEditSheet) {
      BookEditSheet(book: item.book)
    }

  }

  private func addToReadList(readListId: String) {
    Task {
      do {
        try await ReadListService.addBooksToReadList(
          readListId: readListId,
          bookIds: [item.bookId]
        )
        ErrorManager.shared.notify(
          message: String(localized: "notification.book.booksAddedToReadList"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteBook() {
    Task {
      do {
        try await BookService.deleteBook(bookId: item.bookId)
        await CacheManager.clearCache(forBookId: item.bookId)
        ErrorManager.shared.notify(message: String(localized: "notification.book.deleted"))
        onMutationCompleted?()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
