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
  @State private var selectedBookId: String?
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { selectedBookId != nil },
      set: { if !$0 { selectedBookId = nil } }
    )
  }

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
                  .background(themeColorOption.color)
                  .clipShape(Capsule())
                  .padding(4)
              }
            }

            VStack(alignment: .leading, spacing: 8) {
              Text(series.metadata.title)
                .font(.title2)

              // Status
              if let status = series.metadata.status, !status.isEmpty {
                Text(statusDisplayName(status))
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(statusColor(status))
                  .foregroundColor(.white)
                  .cornerRadius(4)
              }

              // Age Rating
              if let ageRating = series.metadata.ageRating, ageRating > 0 {
                Text("\(ageRating)+")
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(ageRating > 16 ? Color.red : Color.green)
                  .foregroundColor(.white)
                  .cornerRadius(4)
              }

              // Language
              if let language = series.metadata.language, !language.isEmpty {
                Text(languageDisplayName(language))
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.secondary.opacity(0.2))
                  .foregroundColor(.primary)
                  .cornerRadius(4)
              }

              // Reading Direction
              if let direction = series.metadata.readingDirection, !direction.isEmpty {
                Text(direction)
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.secondary.opacity(0.2))
                  .foregroundColor(.primary)
                  .cornerRadius(4)
              }

              // Publisher
              if let publisher = series.metadata.publisher, !publisher.isEmpty {
                Text(publisher)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }

              // Books count
              HStack(spacing: 4) {
                if let totalBookCount = series.metadata.totalBookCount {
                  Text("\(series.booksCount) / \(totalBookCount) books")
                } else {
                  Text("\(series.booksCount) books")
                }
              }
              .font(.caption)
              .foregroundColor(.secondary)

              // Release date
              if let releaseDate = series.booksMetadata.releaseDate {
                HStack(spacing: 4) {
                  Image(systemName: "calendar")
                    .font(.caption2)
                  Text(formatReleaseDate(releaseDate))
                }
                .font(.caption)
                .foregroundColor(.secondary)
              }

              // Authors
              if let authors = series.booksMetadata.authors, !authors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                  ForEach(
                    Array(groupAuthorsByRole(authors).sorted(by: { $0.key < $1.key })), id: \.key
                  ) { role, names in
                    HStack(alignment: .top, spacing: 4) {
                      Text("\(roleDisplayName(role)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                      Text(names.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.primary)
                    }
                  }
                }
              }

              // Genres
              if let genres = series.metadata.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 6) {
                    ForEach(genres.sorted(), id: \.self) { genre in
                      Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                  }
                }
              }

              // Tags
              if let tags = series.metadata.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 6) {
                    ForEach(tags.sorted(), id: \.self) { tag in
                      Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                    }
                  }
                }
              }
            }

            Spacer()
          }

          if let summary = series.metadata.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Summary")
                .font(.headline)
              Text(summary)
                .font(.body)
            }
          }

          // Books list
          VStack(alignment: .leading, spacing: 8) {
            Text("Books")
              .font(.headline)

            if bookViewModel.isLoading && bookViewModel.books.isEmpty {
              ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
            } else {
              LazyVStack(spacing: 8) {
                ForEach(bookViewModel.books) { book in
                  Button {
                    selectedBookId = book.id
                  } label: {
                    BookRowView(book: book, viewModel: bookViewModel)
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
            }
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal)
    }
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(isPresented: isBookReaderPresented) {
      if let bookId = selectedBookId {
        BookReaderView(bookId: bookId)
      }
    }
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

  var completed: Bool {
    guard let readProgress = book.readProgress else { return false }
    return readProgress.completed
  }

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
          .foregroundColor(completed ? .secondary : .primary)
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

// Helper functions for SeriesDetailView
extension SeriesDetailView {
  private func statusDisplayName(_ status: String) -> String {
    switch status.uppercased() {
    case "ONGOING":
      return "Ongoing"
    case "ENDED":
      return "Ended"
    case "ABANDONED":
      return "Abandoned"
    case "HIATUS":
      return "Hiatus"
    default:
      return status.capitalized
    }
  }

  private func statusColor(_ status: String) -> Color {
    switch status.uppercased() {
    case "ENDED":
      return Color.green.opacity(0.8)
    case "ABANDONED":
      return Color.red.opacity(0.8)
    case "HIATUS":
      return themeColorOption.color.opacity(0.8)
    default:
      return Color.blue.opacity(0.8)
    }
  }

  private func languageDisplayName(_ language: String) -> String {
    // Simple language code to name mapping
    let languageMap: [String: String] = [
      "en": "English",
      "ja": "Japanese",
      "zh": "Chinese",
      "ko": "Korean",
      "fr": "French",
      "de": "German",
      "es": "Spanish",
      "it": "Italian",
      "pt": "Portuguese",
      "ru": "Russian",
      "ar": "Arabic",
      "th": "Thai",
      "vi": "Vietnamese",
    ]

    // Check if it's a full language code like "en-US" or "zh-CN"
    if language.contains("-") {
      let baseCode = String(language.prefix(2))
      return languageMap[baseCode.lowercased()] ?? language
    }

    return languageMap[language.lowercased()] ?? language.uppercased()
  }

  private func formatReleaseDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")

    if let date = formatter.date(from: dateString) {
      let yearFormatter = DateFormatter()
      yearFormatter.dateFormat = "yyyy"
      yearFormatter.timeZone = TimeZone(identifier: "UTC")
      return yearFormatter.string(from: date)
    }

    return dateString
  }

  private func groupAuthorsByRole(_ authors: [Author]) -> [String: [String]] {
    var grouped: [String: [String]] = [:]
    for author in authors {
      if grouped[author.role] == nil {
        grouped[author.role] = []
      }
      grouped[author.role]?.append(author.name)
    }
    return grouped
  }

  private func roleDisplayName(_ role: String) -> String {
    switch role.lowercased() {
    case "writer", "author":
      return "Writer"
    case "penciller", "artist", "illustrator":
      return "Artist"
    case "colorist":
      return "Colorist"
    case "letterer":
      return "Letterer"
    case "cover":
      return "Cover"
    case "editor":
      return "Editor"
    case "translator":
      return "Translator"
    case "inker":
      return "Inker"
    default:
      return role.capitalized
    }
  }
}
