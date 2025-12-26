//
//  SeriesDetailView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Flow
import SwiftData
import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  // SwiftData query for reactive updates
  @Query private var komgaSeriesList: [KomgaSeries]

  @State private var seriesViewModel = SeriesViewModel()
  @State private var bookViewModel = BookViewModel()
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var containingCollections: [SeriesCollection] = []
  @State private var isLoadingCollections = false
  @State private var containerWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var thumbnailRefreshTrigger = 0

  init(seriesId: String) {
    self.seriesId = seriesId
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(seriesId)"
    _komgaSeriesList = Query(filter: #Predicate<KomgaSeries> { $0.id == compositeId })
  }

  /// The KomgaSeries from SwiftData (reactive).
  private var komgaSeries: KomgaSeries? {
    komgaSeriesList.first
  }

  /// Convert to API Series type for compatibility with existing components.
  private var series: Series? {
    komgaSeries?.toSeries()
  }

  // SwiftUI's default horizontal padding is 16 on each side (32 total)
  private let horizontalPadding: CGFloat = 16

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
          HStack(alignment: .bottom) {
            Text(series.metadata.title)
              .font(.title2)
            if let ageRating = series.metadata.ageRating, ageRating > 0 {
              AgeRatingBadge(ageRating: ageRating)
            }
            Spacer()
          }

          HStack(alignment: .top) {
            ThumbnailImage(
              id: seriesId,
              type: .series,
              showPlaceholder: false,
              width: PlatformHelper.detailThumbnailWidth,
              refreshTrigger: thumbnailRefreshTrigger
            )
            .thumbnailFocus()

            VStack(alignment: .leading) {

              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                  if let totalBookCount = series.metadata.totalBookCount {
                    InfoChip(
                      labelKey: "\(series.booksCount) / \(totalBookCount) books",
                      systemImage: "book",
                      backgroundColor: Color.blue.opacity(0.2),
                      foregroundColor: .blue
                    )
                  } else {
                    InfoChip(
                      labelKey: "\(series.booksCount) books",
                      systemImage: "book",
                      backgroundColor: Color.blue.opacity(0.2),
                      foregroundColor: .blue
                    )
                  }

                  if series.booksUnreadCount > 0 && series.booksUnreadCount < series.booksCount {
                    InfoChip(
                      labelKey: "\(series.booksUnreadCount) unread",
                      systemImage: "circle",
                      backgroundColor: Color.gray.opacity(0.2),
                      foregroundColor: .gray
                    )
                  } else if series.booksInProgressCount > 0 {
                    InfoChip(
                      labelKey: "\(series.booksInProgressCount) in progress",
                      systemImage: "circle.righthalf.filled",
                      backgroundColor: Color.orange.opacity(0.2),
                      foregroundColor: .orange
                    )
                  } else if series.booksUnreadCount == 0 && series.booksCount > 0 {
                    InfoChip(
                      labelKey: "All read",
                      systemImage: "checkmark.circle.fill",
                      backgroundColor: Color.green.opacity(0.2),
                      foregroundColor: .green
                    )
                  }
                }

                if hasReleaseInfo {
                  HStack(spacing: 6) {
                    if let releaseDate = series.booksMetadata.releaseDate {
                      InfoChip(
                        label: releaseDate,
                        systemImage: "calendar",
                        backgroundColor: Color.orange.opacity(0.2),
                        foregroundColor: .orange
                      )
                    }
                    if let status = series.metadata.status, !status.isEmpty {
                      InfoChip(
                        labelKey: series.statusDisplayName,
                        systemImage: series.statusIcon,
                        backgroundColor: series.statusColor.opacity(0.8),
                        foregroundColor: .white
                      )
                    }
                  }
                }

                if hasReadInfo {
                  HStack(spacing: 6) {
                    if let language = series.metadata.language, !language.isEmpty {
                      InfoChip(
                        label: languageDisplayName(language),
                        systemImage: "globe",
                        backgroundColor: Color.purple.opacity(0.2),
                        foregroundColor: .purple
                      )
                    }

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

                if let publisher = series.metadata.publisher, !publisher.isEmpty {
                  InfoChip(
                    label: publisher,
                    systemImage: "building.2",
                    backgroundColor: Color.teal.opacity(0.2),
                    foregroundColor: .teal
                  )
                }

                if let authors = series.booksMetadata.authors, !authors.isEmpty {
                  HFlow {
                    ForEach(authors.sortedByRole(), id: \.self) { author in
                      InfoChip(
                        label: author.name,
                        systemImage: author.role.icon,
                        backgroundColor: Color.indigo.opacity(0.2),
                        foregroundColor: .indigo
                      )
                    }
                  }
                }
              }
            }
          }

          if let genres = series.metadata.genres, !genres.isEmpty {
            HFlow {
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

          if let tags = series.metadata.tags, !tags.isEmpty {
            HFlow {
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

          HStack(spacing: 6) {
            InfoChip(
              labelKey: "Created: \(formatDate(series.created))",
              systemImage: "calendar.badge.plus",
              backgroundColor: Color.blue.opacity(0.2),
              foregroundColor: .blue
            )
            InfoChip(
              labelKey: "Modified: \(formatDate(series.lastModified))",
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

          if let alternateTitles = series.metadata.alternateTitles, !alternateTitles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Divider()
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

          if let links = series.metadata.links, !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Divider()
              Text("Links")
                .font(.headline)
              HFlow {
                ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                  if let url = URL(string: link.url) {
                    Link(destination: url) {
                      InfoChip(
                        label: link.label,
                        systemImage: "link",
                        backgroundColor: Color.blue.opacity(0.2),
                        foregroundColor: .blue
                      )
                    }
                  } else {
                    InfoChip(
                      label: link.label,
                      systemImage: "link",
                      backgroundColor: Color.gray.opacity(0.2),
                      foregroundColor: .gray
                    )
                  }
                }
              }
            }.padding(.bottom, 8)
          }

          if let summary = series.metadata.summary, !summary.isEmpty {
            Divider()
            ExpandableSummaryView(
              summary: summary,
              titleIcon: nil,
              subtitle: nil,
              titleStyle: .headline
            )
          } else if let summary = series.booksMetadata.summary, !summary.isEmpty {
            let subtitle = series.booksMetadata.summaryNumber.map { "(from Book #\($0))" }
            Divider()
            ExpandableSummaryView(
              summary: summary,
              titleIcon: nil,
              subtitle: subtitle,
              titleStyle: .headline
            )
          }

          #if os(tvOS)
            seriesToolbarContent
              .padding(.vertical, 8)
          #endif

          Divider()
          if let komgaSeries = komgaSeries {
            SeriesDownloadActionsSection(komgaSeries: komgaSeries)
          }
          Divider()
          if containerWidth > 0 {
            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
              layoutHelper: layoutHelper,
              showFilterSheet: $showFilterSheet
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(.horizontal, horizontalPadding)
    }
    .inlineNavigationBarTitle(String(localized: "title.series"))
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

extension SeriesDetailView {
  private func presentReader(book: Book, incognito: Bool) {
    readerPresentation.present(book: book, incognito: incognito) {
      refreshAfterReading()
    }
  }

  private func refreshAfterReading() {
    Task {
      await refreshSeriesData()
      // Books list refreshes via SwiftData Query reactivity
    }
  }

  @MainActor
  private func refreshSeriesData() async {
    await loadSeriesDetails()
  }

  @MainActor
  private func loadSeriesDetails() async {
    do {
      // Sync from network to SwiftData (series property will update reactively)
      let fetchedSeries = try await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await loadSeriesCollections(seriesId: fetchedSeries.id)
      reloadThumbnail()
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaSeries == nil {
        ErrorManager.shared.alert(error: error)
      }
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
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.analysisStarted"))
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
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.metadataRefreshed"))
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
          ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
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
          ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
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
          ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
          dismiss()
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func reloadThumbnail() {
    guard !AppConfig.isOffline else { return }
    thumbnailRefreshTrigger += 1
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.shared.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        // Sync the collection to update its seriesIds in local SwiftData
        _ = try? await SyncService.shared.syncCollection(id: collectionId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "notification.series.addedToCollection"))
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
    LanguageCodeHelper.displayName(for: language)
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
      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
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
