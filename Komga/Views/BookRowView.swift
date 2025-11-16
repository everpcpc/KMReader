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
  @State private var thumbnail: UIImage?

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
      if let thumbnail = thumbnail {
        Image(uiImage: thumbnail)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 60, height: 80)
          .clipped()
          .cornerRadius(4)
      } else {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 60, height: 80)
          .cornerRadius(4)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("#\(formatNumber(book.number)) - \(book.metadata.title)")
          .font(.callout)
          .foregroundColor(completed ? .secondary : .primary)
          .lineLimit(2)

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

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
    }
    .animation(.default, value: thumbnail)
    .bookContextMenu(book: book, viewModel: viewModel)
    .task {
      thumbnail = await viewModel.loadThumbnail(for: book.id)
    }
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
