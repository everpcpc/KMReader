//
//  BookCardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// MARK: - Book Context Menu

struct BookContextMenuModifier: ViewModifier {
  let book: Book
  let viewModel: BookViewModel
  var onNavigateToSeries: ((String) -> Void)? = nil

  private var isCompleted: Bool {
    book.readProgress?.completed ?? false
  }

  func body(content: Content) -> some View {
    content.contextMenu {
      // Mark as read
      if !isCompleted {
        Button {
          Task {
            await viewModel.markAsRead(bookId: book.id)
          }
        } label: {
          Label("Mark as Read", systemImage: "checkmark.circle")
        }
      }

      // Mark as unread
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

      // Clear cache
      Button(role: .destructive) {
        Task {
          await ImageCache.clearDiskCache(forBookId: book.id)
        }
      } label: {
        Label("Clear Cache", systemImage: "trash")
      }

      // Navigate to series
      if let onNavigateToSeries = onNavigateToSeries {
        Divider()
        Button {
          onNavigateToSeries(book.seriesId)
        } label: {
          Label("Go to Series", systemImage: "book.fill")
        }
      }
    }
  }
}

extension View {
  func bookContextMenu(
    book: Book,
    viewModel: BookViewModel,
    onNavigateToSeries: ((String) -> Void)? = nil
  ) -> some View {
    modifier(
      BookContextMenuModifier(
        book: book,
        viewModel: viewModel,
        onNavigateToSeries: onNavigateToSeries
      )
    )
  }
}

struct BookCardView: View {
  let book: Book
  var viewModel: BookViewModel
  let cardWidth: CGFloat
  var onNavigateToSeries: ((String) -> Void)? = nil
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
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
          Group {
            if book.deleted {
              DeletedBadge()
            } else if book.readProgress == nil {
              Circle()
                .fill(themeColorOption.color)
                .frame(width: 12, height: 12)
            }
          }
          .padding(4)
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

        Text("\(book.media.pagesCount) pages · \(book.size)")
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .frame(width: cardWidth, alignment: .leading)
    }
    .bookContextMenu(
      book: book,
      viewModel: viewModel,
      onNavigateToSeries: onNavigateToSeries
    )
  }
}
