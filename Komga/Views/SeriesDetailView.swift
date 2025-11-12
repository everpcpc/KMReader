//
//  SeriesDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @State private var seriesViewModel = SeriesViewModel()
  @State private var bookViewModel = BookViewModel()
  @State private var series: Series?
  @State private var thumbnail: UIImage?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let series = series {
          // Header with thumbnail and info
          HStack(alignment: .top, spacing: 16) {
            ZStack {
              if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 120, height: 180)
                  .clipped()
                  .cornerRadius(8)
              } else {
                Rectangle()
                  .fill(Color.gray.opacity(0.3))
                  .frame(width: 120, height: 180)
                  .cornerRadius(8)
              }
            }
            .frame(width: 120, height: 180)
            .clipped()
            .cornerRadius(8)
            .overlay(alignment: .topTrailing) {
              if series.booksUnreadCount > 0 {
                Text("\(series.booksUnreadCount)")
                  .font(.caption)
                  .fontWeight(.bold)
                  .foregroundColor(.white)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.orange)
                  .clipShape(Capsule())
                  .padding(4)
              }
            }

            VStack(alignment: .leading, spacing: 8) {
              Text(series.metadata.title)
                .font(.title2)
                .fontWeight(.bold)

              if let publisher = series.metadata.publisher, !publisher.isEmpty {
                Text(publisher)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }

              HStack {
                Label("\(series.booksCount)", systemImage: "book")
              }
              .font(.caption)
            }

            Spacer()
          }
          .padding()

          if let summary = series.metadata.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Summary")
                .font(.headline)
              Text(summary)
                .font(.body)
            }
            .padding(.horizontal)
          }

          // Books list
          VStack(alignment: .leading, spacing: 8) {
            Text("Books")
              .font(.headline)
              .padding(.horizontal)

            if bookViewModel.isLoading && bookViewModel.books.isEmpty {
              ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
            } else {
              LazyVStack(spacing: 8) {
                ForEach(bookViewModel.books) { book in
                  NavigationLink(destination: BookReaderView(bookId: book.id)) {
                    BookRowView(book: book, viewModel: bookViewModel)
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
              .padding(.horizontal)
            }
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .task {
      // Load series details
      do {
        series = try await SeriesService.shared.getOneSeries(id: seriesId)
        thumbnail = await seriesViewModel.loadThumbnail(for: seriesId)
        await bookViewModel.loadBooks(seriesId: seriesId)
      } catch {
        print("Error loading series: \(error)")
      }
    }
  }
}

struct BookRowView: View {
  let book: Book
  var viewModel: BookViewModel
  @State private var thumbnail: UIImage?

  var body: some View {
    HStack(spacing: 12) {
      if let thumbnail = thumbnail {
        Image(uiImage: thumbnail)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 60, height: 90)
          .clipped()
          .cornerRadius(4)
      } else {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 60, height: 90)
          .cornerRadius(4)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(book.metadata.title)
          .font(.subheadline)
          .foregroundColor(.primary)
          .lineLimit(2)

        HStack(spacing: 4) {
          Text("#\(formatNumber(book.number))")
            .fontWeight(.medium)
            .foregroundColor(.secondary)

          Text("•")
            .foregroundColor(.secondary)

          Text("\(book.media.pagesCount) pages")
            .foregroundColor(.secondary)

          if let progress = book.readProgress {
            Text("•")
              .foregroundColor(.secondary)

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

        HStack(spacing: 4) {
          Label(book.size, systemImage: "doc")
          Text("•")
          Label(formatDate(book.created), systemImage: "clock")
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
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

#Preview {
  NavigationView {
    SeriesDetailView(seriesId: "1")
  }
}
