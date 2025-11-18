//
//  BookRowView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookRowView: View {
  let book: Book
  var viewModel: BookViewModel

  private var thumbnailURL: URL? {
    BookService.shared.getBookThumbnailURL(id: book.id)
  }

  var completed: Bool {
    guard let readProgress = book.readProgress else { return false }
    return readProgress.completed
  }

  private var isInProgress: Bool {
    guard let readProgress = book.readProgress else { return false }
    return !readProgress.completed
  }

  var body: some View {
    HStack(spacing: 12) {
      ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 60, cornerRadius: 4)

      VStack(alignment: .leading, spacing: 4) {
        Text("#\(formatNumber(book.number)) - \(book.metadata.title)")
          .font(.callout)
          .foregroundColor(completed ? .secondary : .primary)
          .lineLimit(2)

        if book.deleted {
          DeletedBadge()
        } else {
          HStack(spacing: 4) {
            Label(formatDate(book.created), systemImage: "clock")
            if let progress = book.readProgress {
              Text("•")
              if progress.completed {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              } else {
                Text("Page \(progress.page + 1)")
                  .foregroundColor(.blue)
              }
            }
          }
          .font(.caption)
          .foregroundColor(.secondary)

          HStack(spacing: 4) {
            Text("\(book.media.pagesCount) pages")
            Text("•")
            Label(book.size, systemImage: "doc")
          }
          .foregroundColor(.secondary)
          .font(.footnote)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
    }
    .bookContextMenu(book: book, viewModel: viewModel)
  }

  private func formatNumber(_ number: Double) -> String {
    if number.truncatingRemainder(dividingBy: 1) == 0 {
      return String(format: "%.0f", number)
    } else {
      return String(format: "%.1f", number)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(date) {
      formatter.dateStyle = .none
      formatter.timeStyle = .short
      return formatter.string(from: date)
    }

    if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
      formatter.dateFormat = "MM-dd"
      return formatter.string(from: date)
    }

    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
