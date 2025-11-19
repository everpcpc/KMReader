//
//  SeriesDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange
  @AppStorage("bookListSortDirection") private var sortDirection: SortDirection = .ascending

  @Environment(\.dismiss) private var dismiss

  @State private var seriesViewModel = SeriesViewModel()
  @State private var bookViewModel = BookViewModel()
  @State private var series: Series?
  @State private var readerState: BookReaderState?
  @State private var actionErrorMessage: String?
  @State private var showDeleteConfirmation = false

  private var thumbnailURL: URL? {
    guard let series = series else { return nil }
    return SeriesService.shared.getSeriesThumbnailURL(id: series.id)
  }

  private var isBookReaderPresented: Binding<Bool> {
    Binding(
      get: { readerState != nil },
      set: { if !$0 { readerState = nil } }
    )
  }

  private var isActionErrorPresented: Binding<Bool> {
    Binding(
      get: { actionErrorMessage != nil },
      set: { if !$0 { actionErrorMessage = nil } }
    )
  }

  private var canMarkSeriesAsRead: Bool {
    guard let series else { return false }
    return series.booksUnreadCount > 0
  }

  private var canMarkSeriesAsUnread: Bool {
    guard let series else { return false }
    return (series.booksReadCount + series.booksInProgressCount) > 0
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let series = series {
          // Header with thumbnail and info
          HStack(alignment: .top, spacing: 16) {
            ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)
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

            VStack(alignment: .leading) {
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

              HStack(spacing: 4) {
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
                  Text(ReadingDirection.fromString(direction).displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(4)
                }
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
                  Image(systemName: "calendar.badge.clock")
                    .font(.caption2)
                  Text(releaseDate)
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

          // Summary section - show series summary or first book summary if available
          if let summary = series.metadata.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Summary")
                .font(.headline)
              Text(summary)
                .font(.body)
            }
          } else if let summary = series.booksMetadata.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Summary")
                  .font(.headline)
                if let number = series.booksMetadata.summaryNumber, !number.isEmpty {
                  Text("(from Book #\(number))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              Text(summary)
                .font(.body)
            }
          }

          // Books list
          BooksListView(
            seriesId: seriesId,
            bookViewModel: bookViewModel,
            onReadBook: { bookId, incognito in
              readerState = BookReaderState(bookId: bookId, incognito: incognito)
            }
          )
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal)
    }
    .navigationTitle("Series")
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(
      isPresented: isBookReaderPresented,
      onDismiss: {
        refreshAfterReading()
      }
    ) {
      if let state = readerState, let bookId = state.bookId {
        BookReaderView(bookId: bookId, incognito: state.incognito)
      }
    }
    .alert("Action Failed", isPresented: isActionErrorPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      if let actionErrorMessage {
        Text(actionErrorMessage)
      }
    }
    .alert("Delete Series?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(series?.metadata.title ?? "this series") from Komga.")
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if series != nil {
            if canMarkSeriesAsRead {
              Button {
                markSeriesAsRead()
              } label: {
                Label("Mark as Read", systemImage: "checkmark.circle")
              }
            }

            if canMarkSeriesAsUnread {
              Button {
                markSeriesAsUnread()
              } label: {
                Label("Mark as Unread", systemImage: "circle")
              }
            }
          }

          Divider()

          Button {
            analyzeSeries()
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }

          Button {
            refreshSeriesMetadata()
          } label: {
            Label("Refresh Metadata", systemImage: "arrow.clockwise")
          }

          Divider()

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Series", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .task {
      await loadSeriesDetails()
    }
  }
}

// Helper functions for SeriesDetailView
extension SeriesDetailView {
  private func refreshAfterReading() {
    Task {
      await refreshSeriesData()
    }
  }

  @MainActor
  private func refreshSeriesData() async {
    await loadSeriesDetails()
    await bookViewModel.loadBooks(seriesId: seriesId, sort: sortDirection.bookSortString)
  }

  @MainActor
  private func loadSeriesDetails() async {
    do {
      let fetchedSeries = try await SeriesService.shared.getOneSeries(id: seriesId)
      series = fetchedSeries
    } catch {
    }
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.shared.analyzeSeries(seriesId: seriesId)
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func refreshSeriesMetadata() {
    Task {
      do {
        try await SeriesService.shared.refreshMetadata(seriesId: seriesId)
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.shared.markAsRead(seriesId: seriesId)
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.shared.markAsUnread(seriesId: seriesId)
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: seriesId)
        await MainActor.run {
          dismiss()
        }
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
    }
  }

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
