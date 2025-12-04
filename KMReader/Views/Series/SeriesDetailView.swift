//
//  SeriesDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("browseLayout") private var layoutMode: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var seriesViewModel = SeriesViewModel()
  @State private var bookViewModel = BookViewModel()
  @State private var series: Series?
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false
  @State private var showEditSheet = false
  @State private var containingCollections: [KomgaCollection] = []
  @State private var isLoadingCollections = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()

  // SwiftUI's default horizontal padding is 16 on each side (32 total)
  private let horizontalPadding: CGFloat = 16

  private var thumbnailURL: URL? {
    guard let series = series else { return nil }
    return SeriesService.shared.getSeriesThumbnailURL(id: series.id)
  }

  private var canMarkSeriesAsRead: Bool {
    guard let series else { return false }
    return series.booksUnreadCount > 0
  }

  private var canMarkSeriesAsUnread: Bool {
    guard let series else { return false }
    return (series.booksReadCount + series.booksInProgressCount) > 0
  }

  private var hasReleaseInfo: Bool {
    guard let series else { return false }
    if let releaseDate = series.booksMetadata.releaseDate, !releaseDate.isEmpty {
      return true
    }
    if let status = series.metadata.status, !status.isEmpty {
      return true
    }

    return false
  }

  private var hasReadInfo: Bool {
    guard let series else { return false }
    if let language = series.metadata.language, !language.isEmpty {
      return true
    }
    if let direction = series.metadata.readingDirection, !direction.isEmpty {
      return true
    }
    return false
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let series = series {
          // Header with thumbnail and info
          HStack {
            Text(series.metadata.title)
              .font(.title3)
            Spacer()
            if let ageRating = series.metadata.ageRating, ageRating > 0 {
              InfoChip(
                label: "\(ageRating)+",
                backgroundColor: ageRating > 16 ? Color.red : Color.green,
                foregroundColor: .white
              )
            }
          }

          HStack(alignment: .top) {
            ThumbnailImage(
              url: thumbnailURL, showPlaceholder: false, width: PlatformHelper.detailThumbnailWidth
            )
            .thumbnailFocus()

            VStack(alignment: .leading) {

              // Status and info chips
              VStack(alignment: .leading, spacing: 6) {
                // First row: Books count and read status
                HStack(spacing: 6) {
                  // Books count
                  if let totalBookCount = series.metadata.totalBookCount {
                    InfoChip(
                      label: "\(series.booksCount) / \(totalBookCount) books",
                      systemImage: "book",
                      backgroundColor: Color.blue.opacity(0.2),
                      foregroundColor: .blue
                    )
                  } else {
                    InfoChip(
                      label: "\(series.booksCount) books",
                      systemImage: "book",
                      backgroundColor: Color.blue.opacity(0.2),
                      foregroundColor: .blue
                    )
                  }

                  // Unread count, in progress, or complete
                  if series.booksUnreadCount > 0 && series.booksUnreadCount < series.booksCount {
                    InfoChip(
                      label: "\(series.booksUnreadCount) unread",
                      systemImage: "circle",
                      backgroundColor: Color.gray.opacity(0.2),
                      foregroundColor: .gray
                    )
                  } else if series.booksInProgressCount > 0 {
                    InfoChip(
                      label: "\(series.booksInProgressCount) in progress",
                      systemImage: "circle.righthalf.filled",
                      backgroundColor: Color.orange.opacity(0.2),
                      foregroundColor: .orange
                    )
                  } else if series.booksUnreadCount == 0 && series.booksCount > 0 {
                    InfoChip(
                      label: "All read",
                      systemImage: "checkmark.circle.fill",
                      backgroundColor: Color.green.opacity(0.2),
                      foregroundColor: .green
                    )
                  }
                }

                if hasReleaseInfo {
                  HStack(spacing: 6) {
                    // Release date chip
                    if let releaseDate = series.booksMetadata.releaseDate {
                      InfoChip(
                        label: releaseDate,
                        systemImage: "calendar",
                        backgroundColor: Color.orange.opacity(0.2),
                        foregroundColor: .orange
                      )
                    }
                    // Status chip
                    if let status = series.metadata.status, !status.isEmpty {
                      InfoChip(
                        label: series.statusDisplayName,
                        systemImage: series.statusIcon,
                        backgroundColor: series.statusColor.opacity(0.8),
                        foregroundColor: .white
                      )
                    }
                  }
                }

                if hasReadInfo {
                  HStack(spacing: 6) {
                    // Language chip
                    if let language = series.metadata.language, !language.isEmpty {
                      InfoChip(
                        label: languageDisplayName(language),
                        systemImage: "globe",
                        backgroundColor: Color.purple.opacity(0.2),
                        foregroundColor: .purple
                      )
                    }

                    // Reading direction chip
                    if let direction = series.metadata.readingDirection, !direction.isEmpty {
                      InfoChip(
                        label: ReadingDirection.fromString(direction).displayName,
                        systemImage: ReadingDirection.fromString(direction).icon,
                        backgroundColor: Color.cyan.opacity(0.2),
                        foregroundColor: .cyan
                      )
                    }
                  }
                }

                // Publisher
                if let publisher = series.metadata.publisher, !publisher.isEmpty {
                  InfoChip(
                    label: publisher,
                    systemImage: "building.2",
                    backgroundColor: Color.teal.opacity(0.2),
                    foregroundColor: .teal
                  )
                }

                // Authors as chips
                if let authors = series.booksMetadata.authors, !authors.isEmpty {
                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                      ForEach(authors, id: \.name) { author in
                        InfoChip(
                          label: author.name,
                          systemImage: "person",
                          backgroundColor: Color.indigo.opacity(0.2),
                          foregroundColor: .indigo
                        )
                      }
                    }
                  }
                }
              }
            }
          }

          // Genres
          if let genres = series.metadata.genres, !genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(genres.sorted(), id: \.self) { genre in
                  InfoChip(
                    label: genre,
                    systemImage: "bookmark",
                    backgroundColor: Color.blue.opacity(0.1),
                    foregroundColor: .blue,
                    cornerRadius: 8
                  )
                }
              }
            }
          }

          // Tags
          if let tags = series.metadata.tags, !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(tags.sorted(), id: \.self) { tag in
                  InfoChip(
                    label: tag,
                    systemImage: "tag",
                    backgroundColor: Color.secondary.opacity(0.1),
                    foregroundColor: .secondary,
                    cornerRadius: 8
                  )
                }
              }
            }
          }

          // Created and last modified dates
          HStack(spacing: 6) {
            InfoChip(
              label: "Created: \(formatDate(series.created))",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              label: "Modified: \(formatDate(series.lastModified))",
              systemImage: "clock",
              backgroundColor: Color.purple.opacity(0.2),
              foregroundColor: .purple
            )
          }

          if !isLoadingCollections && !containingCollections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 4) {
                Text("Collections")
                  .font(.headline)
              }
              .foregroundColor(.secondary)

              VStack(alignment: .leading, spacing: 8) {
                ForEach(containingCollections) { collection in
                  NavigationLink {
                    CollectionDetailView(collectionId: collection.id)
                  } label: {
                    HStack {
                      Label(collection.name, systemImage: "square.grid.2x2")
                        .foregroundColor(.primary)
                      Spacer()
                      Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(16)
                  }
                }
              }
            }
            .padding(.top, 8)
          }

          // Alternate titles
          if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Alternate Titles")
                .font(.headline)
              VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(alternateTitles.enumerated()), id: \.offset) { index, altTitle in
                  HStack(alignment: .top, spacing: 4) {
                    Text("\(altTitle.label):")
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .frame(width: 60, alignment: .leading)
                    Text(altTitle.title)
                      .font(.caption)
                      .foregroundColor(.primary)
                  }
                }
              }
            }.padding(.bottom, 8)
          }

          // Links
          if let links = series.metadata.links, !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Links")
                .font(.headline)
              VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                  if let url = URL(string: link.url) {
                    Link(destination: url) {
                      HStack(spacing: 4) {
                        Image(systemName: "link")
                          .font(.caption)
                        Text(link.label)
                          .font(.caption)
                          .foregroundColor(.blue)
                        Spacer()
                      }
                    }
                  } else {
                    HStack(spacing: 4) {
                      Image(systemName: "link")
                        .font(.caption)
                      Text(link.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                      Text("(\(link.url))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                      Spacer()
                    }
                  }
                }
              }
            }.padding(.bottom, 8)
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

          #if os(tvOS)
            seriesToolbarContent
              .padding(.vertical, 8)
          #endif

          // Books list
          if containerWidth > 0 {
            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
              onReadBook: { book, incognito in
                presentReader(book: book, incognito: incognito)
              },
              layoutMode: layoutMode,
              layoutHelper: layoutHelper
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal, horizontalPadding)
    }
    .inlineNavigationBarTitle("Series")
    .alert("Delete Series?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(series?.metadata.title ?? "this series") from Komga.")
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          seriesToolbarContent
        }
      }
    #endif
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
    .sheet(isPresented: $showEditSheet) {
      if let series = series {
        SeriesEditSheet(series: series)
          .onDisappear {
            Task {
              await refreshSeriesData()
            }
          }
      }
    }
    .task {
      await loadSeriesDetails()
    }
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { newSize in
      let newContentWidth = max(0, newSize.width - horizontalPadding * 2)
      if abs(containerWidth - newSize.width) > 1 {
        containerWidth = newSize.width
        layoutHelper = BrowseLayoutHelper(
          width: newContentWidth,
          browseColumns: browseColumns
        )
      }
    }
    .onChange(of: browseColumns) { _, _ in
      if containerWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: containerWidth - horizontalPadding * 2,
          browseColumns: browseColumns
        )
      }
    }
  }
}

// Helper functions for SeriesDetailView
extension SeriesDetailView {
  private func presentReader(book: Book, incognito: Bool) {
    readerPresentation.present(book: book, incognito: incognito) {
      refreshAfterReading()
    }
  }

  private func refreshAfterReading() {
    Task {
      await refreshSeriesData()
      // Refresh book list smoothly without clearing existing data
      await bookViewModel.refreshCurrentBooks()
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
      withAnimation {
        series = fetchedSeries
      }
      await loadSeriesCollections(seriesId: fetchedSeries.id)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  @MainActor
  private func loadSeriesCollections(seriesId: String) async {
    isLoadingCollections = true
    containingCollections = []
    do {
      let collections = try await SeriesService.shared.getSeriesCollections(seriesId: seriesId)
      withAnimation {
        containingCollections = collections
      }
    } catch {
      containingCollections = []
      ErrorManager.shared.alert(error: error)
    }
    isLoadingCollections = false
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.shared.analyzeSeries(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series analysis started")
        }
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func refreshSeriesMetadata() {
    Task {
      do {
        try await SeriesService.shared.refreshMetadata(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series metadata refreshed")
        }
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.shared.markAsRead(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series marked as read")
        }
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.shared.markAsUnread(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series marked as unread")
        }
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.shared.deleteSeries(seriesId: seriesId)
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series deleted")
          dismiss()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
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
        await MainActor.run {
          ErrorManager.shared.notify(message: "Series added to collection")
        }
        await refreshSeriesData()
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
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

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  @ViewBuilder
  private var seriesToolbarContent: some View {
    HStack(spacing: PlatformHelper.buttonSpacing) {
      Menu {
        Picker("Layout", selection: $layoutMode) {
          ForEach(BrowseLayoutMode.allCases) { mode in
            Label(mode.displayName, systemImage: mode.iconName).tag(mode)
          }
        }
        .pickerStyle(.inline)
      } label: {
        Label("Layout", systemImage: layoutMode.iconName)
          .labelStyle(.iconOnly)
      }
      .toolbarButtonStyle()

      Menu {
        Button {
          showEditSheet = true
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .disabled(!isAdmin)

        Divider()

        Button {
          analyzeSeries()
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(!isAdmin)

        Button {
          refreshSeriesMetadata()
        } label: {
          Label("Refresh Metadata", systemImage: "arrow.clockwise")
        }
        .disabled(!isAdmin)

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
        .disabled(!isAdmin)
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .toolbarButtonStyle()
    }
  }
}
