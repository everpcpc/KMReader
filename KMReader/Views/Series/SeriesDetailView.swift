//
//  SeriesDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("seriesDetailLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()

  @Environment(\.dismiss) private var dismiss

  @State private var seriesViewModel = SeriesViewModel()
  @State private var bookViewModel = BookViewModel()
  @State private var series: Series?
  @State private var readerState: BookReaderState?
  @State private var actionErrorMessage: String?
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false

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
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let series = series {
            // Header with thumbnail and info
            HStack(alignment: .top, spacing: 16) {
              ThumbnailImage(url: thumbnailURL, showPlaceholder: false, width: 120)

              VStack(alignment: .leading) {
                Text(series.metadata.title)
                  .font(.title2)

                // Status and info chips
                VStack(alignment: .leading, spacing: 6) {
                  // First row: Books count and read status
                  HStack(spacing: 6) {
                    // Books count
                    if let totalBookCount = series.metadata.totalBookCount {
                      InfoChip(
                        label: "\(series.booksCount) / \(totalBookCount) books",
                        systemImage: "books.vertical",
                        backgroundColor: Color.blue.opacity(0.2),
                        foregroundColor: .blue
                      )
                    } else {
                      InfoChip(
                        label: "\(series.booksCount) books",
                        systemImage: "books.vertical",
                        backgroundColor: Color.blue.opacity(0.2),
                        foregroundColor: .blue
                      )
                    }

                    // Unread count, in progress, or complete
                    if series.booksUnreadCount > 0 {
                      InfoChip(
                        label: "\(series.booksUnreadCount) unread",
                        systemImage: "book",
                        backgroundColor: themeColor.color.opacity(0.2),
                        foregroundColor: themeColor.color
                      )
                    } else if series.booksInProgressCount > 0 {
                      InfoChip(
                        label: "\(series.booksInProgressCount) in progress",
                        systemImage: "book.pages",
                        backgroundColor: Color.orange.opacity(0.2),
                        foregroundColor: .orange
                      )
                    } else {
                      InfoChip(
                        label: "Complete",
                        systemImage: "checkmark.circle.fill",
                        backgroundColor: Color.green.opacity(0.2),
                        foregroundColor: .green
                      )
                    }
                  }

                  // Additional rows: Status, Age Rating, Language, Reading Direction (max 2 per row)
                  if let status = series.metadata.status, !status.isEmpty {
                    HStack(spacing: 6) {
                      InfoChip(
                        label: series.statusDisplayName,
                        backgroundColor: series.statusColor.opacity(0.8),
                        foregroundColor: .white
                      )
                      if let ageRating = series.metadata.ageRating, ageRating > 0 {
                        InfoChip(
                          label: "\(ageRating)+",
                          backgroundColor: ageRating > 16 ? Color.red : Color.green,
                          foregroundColor: .white
                        )
                      } else {
                        Spacer()
                      }
                    }
                  } else if let ageRating = series.metadata.ageRating, ageRating > 0 {
                    HStack(spacing: 6) {
                      InfoChip(
                        label: "\(ageRating)+",
                        backgroundColor: ageRating > 16 ? Color.red : Color.green,
                        foregroundColor: .white
                      )
                      Spacer()
                    }
                  }

                  if let language = series.metadata.language, !language.isEmpty {
                    HStack(spacing: 6) {
                      InfoChip(
                        label: languageDisplayName(language),
                        backgroundColor: Color.purple.opacity(0.2),
                        foregroundColor: .purple
                      )
                      if let direction = series.metadata.readingDirection, !direction.isEmpty {
                        InfoChip(
                          label: ReadingDirection.fromString(direction).displayName,
                          backgroundColor: Color.cyan.opacity(0.2),
                          foregroundColor: .cyan
                        )
                      } else {
                        Spacer()
                      }
                    }
                  } else if let direction = series.metadata.readingDirection, !direction.isEmpty {
                    HStack(spacing: 6) {
                      InfoChip(
                        label: ReadingDirection.fromString(direction).displayName,
                        backgroundColor: Color.cyan.opacity(0.2),
                        foregroundColor: .cyan
                      )
                      Spacer()
                    }
                  }

                  // Created and last modified dates
                  InfoChip(
                    label: series.created.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar.badge.plus",
                    backgroundColor: Color.blue.opacity(0.2),
                    foregroundColor: .blue
                  )
                  InfoChip(
                    label: series.lastModified.formatted(
                      date: .abbreviated, time: .omitted),
                    systemImage: "clock",
                    backgroundColor: Color.purple.opacity(0.2),
                    foregroundColor: .purple
                  )
                }

                // Publisher
                if let publisher = series.metadata.publisher, !publisher.isEmpty {
                  Text(publisher)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                // Release date chip
                if let releaseDate = series.booksMetadata.releaseDate {
                  InfoChip(
                    label: releaseDate,
                    systemImage: "calendar.badge.clock",
                    backgroundColor: Color.orange.opacity(0.2),
                    foregroundColor: .orange
                  )
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
            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
              onReadBook: { bookId, incognito in
                readerState = BookReaderState(bookId: bookId, incognito: incognito)
              },
              layoutMode: layoutMode,
              layoutHelper: BrowseLayoutHelper(
                width: geometry.size.width - 32,
                height: geometry.size.height,
                spacing: 12,
                browseColumns: browseColumns
              )
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
          HStack(spacing: 8) {
            Menu {
              Picker("Layout", selection: $layoutMode) {
                ForEach(BrowseLayoutMode.allCases) { mode in
                  Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
              }
              .pickerStyle(.inline)
            } label: {
              Image(systemName: layoutMode.iconName)
            }

            Menu {
              Button {
                analyzeSeries()
              } label: {
                Label("Analyze", systemImage: "waveform.path.ecg")
              }
              .disabled(!AppConfig.isAdmin)

              Button {
                refreshSeriesMetadata()
              } label: {
                Label("Refresh Metadata", systemImage: "arrow.clockwise")
              }
              .disabled(!AppConfig.isAdmin)

              Divider()

              Button {
                showCollectionPicker = true
              } label: {
                Label("Add to Collection", systemImage: "square.grid.2x2")
              }

              Divider()

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

              Button(role: .destructive) {
                showDeleteConfirmation = true
              } label: {
                Label("Delete Series", systemImage: "trash")
              }
              .disabled(!AppConfig.isAdmin)
            } label: {
              Image(systemName: "ellipsis.circle")
            }
          }
        }
      }
      .sheet(isPresented: $showCollectionPicker) {
        CollectionPickerSheet(
          seriesIds: [seriesId],
          onSelect: { collectionId in
            addToCollection(collectionId: collectionId)
          },
          onComplete: {
            // Create already adds series, just refresh
            Task {
              await refreshSeriesData()
            }
          }
        )
      }
      .task {
        await loadSeriesDetails()
      }
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

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          actionErrorMessage = error.localizedDescription
        }
      }
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
