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
          BooksListView(seriesId: seriesId, selectedBookId: $selectedBookId)
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
      } catch {
        print("Error loading series: \(error)")
      }
    }
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
