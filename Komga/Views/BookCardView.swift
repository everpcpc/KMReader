//
//  BookCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// MARK: - Book Context Menu

@MainActor
struct BookContextMenu: View {
  let book: Book
  let viewModel: BookViewModel
  var onReadBook: ((Bool) -> Void)?

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
  }

  var body: some View {
    Group {
      if let onReadBook = onReadBook {
        Button {
          onReadBook(false)
        } label: {
          Label("Read Book", systemImage: "book.pages")
        }
        Button {
          onReadBook(true)
        } label: {
          Label("Read Incognito", systemImage: "eye.slash")
        }
      }

      Divider()

      NavigationLink(value: NavigationDestination.bookDetail(bookId: book.id)) {
        Label("View Details", systemImage: "info.circle")
      }
      NavigationLink(value: NavigationDestination.seriesDetail(seriesId: book.seriesId)) {
        Label("Go to Series", systemImage: "book.fill")
      }

      Divider()

      if !isCompleted {
        Button {
          Task {
            await viewModel.markAsRead(bookId: book.id)
          }
        } label: {
          Label("Mark as Read", systemImage: "checkmark.circle")
        }
      }
      if book.readProgress != nil {
        Button {
          Task {
            await viewModel.markAsUnread(bookId: book.id)
          }
        } label: {
          Label("Mark as Unread", systemImage: "circle")
        }
      }

      Divider()

      Button(role: .destructive) {
        Task {
          await ImageCache.clearDiskCache(forBookId: book.id)
        }
      } label: {
        Label("Clear Cache", systemImage: "trash")
      }
    }
  }
}

struct BookReaderState {
  var bookId: String?
  var incognito: Bool = false
}

struct BookCardView: View {
  let book: Book
  var viewModel: BookViewModel
  let cardWidth: CGFloat
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @State private var readerState: BookReaderState?

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  private var progress: Double {
    guard let readProgress = book.readProgress else { return 0 }
    guard book.media.pagesCount > 0 else { return 0 }
    return Double(readProgress.page) / Double(book.media.pagesCount)
  }

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
  }

  private var isInProgress: Bool {
    guard let readProgress = book.readProgress else { return false }
    return !readProgress.completed
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ThumbnailImage(url: thumbnailURL, width: cardWidth)
        .overlay(alignment: .topTrailing) {
          if book.readProgress == nil {
            Circle()
              .fill(themeColorOption.color)
              .frame(width: 12, height: 12)
              .padding(4)
          }
        }
        .overlay(alignment: .topTrailing) {
          if book.readProgress == nil {
            Circle()
              .fill(themeColorOption.color)
              .frame(width: 12, height: 12)
              .padding(4)
          }
        }
        .overlay(alignment: .bottom) {
          if isInProgress {
            GeometryReader { geometry in
              ZStack(alignment: .leading) {
                Rectangle()
                  .fill(Color.gray.opacity(0.2))
                  .frame(height: 4)
                  .cornerRadius(2)

                Rectangle()
                  .fill(themeColorOption.color)
                  .frame(width: geometry.size.width * progress, height: 4)
                  .cornerRadius(2)
              }
            }
            .frame(height: 4)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
          }
        }

      VStack(alignment: .leading, spacing: 2) {
        Text(book.seriesTitle)
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)

        Text("\(book.metadata.number) - \(book.metadata.title)")
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)

        Group {
          if book.deleted {
            Text("Unavailable")
              .foregroundColor(.red)
          } else {
            Text("\(book.media.pagesCount) pages · \(book.size)")
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }.font(.caption2)
      }
      .frame(width: cardWidth, alignment: .leading)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      readerState = BookReaderState(bookId: book.id, incognito: false)
    }
    .contextMenu {
      BookContextMenu(
        book: book,
        viewModel: viewModel,
        onReadBook: { incognito in
          readerState = BookReaderState(bookId: book.id, incognito: incognito)
        }
      )
    }
    .fullScreenCover(isPresented: isBookReaderPresented) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
  }
}
