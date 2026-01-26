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

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("seriesDetailLayout") private var seriesDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @Query private var komgaSeriesList: [KomgaSeries]

  @State private var bookViewModel = BookViewModel()
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(seriesId: String) {
    self.seriesId = seriesId
    let compositeId = CompositeID.generate(id: seriesId)
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

  private var canMarkSeriesAsRead: Bool {
    guard let series else { return false }
    return series.booksUnreadCount > 0
  }

  private var canMarkSeriesAsUnread: Bool {
    guard let series else { return false }
    return (series.booksReadCount + series.booksInProgressCount) > 0
  }

  private var canRead: Bool {
    guard let series, !series.deleted else { return false }
    return (series.booksUnreadCount + series.booksInProgressCount) > 0
  }

  private var readLabel: String {
    if let readCount = series?.booksReadCount, readCount > 0 {
      return String(localized: "Resume Reading")
    } else {
      return String(localized: "Start Reading")
    }
  }

  private var navigationTitle: String {
    series?.metadata.title ?? String(localized: "Series")
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading) {
        if let series = series {
          VStack(alignment: .leading) {
            #if os(tvOS)
              seriesToolbarContent
                .padding(.vertical, 8)
            #endif

            SeriesDetailContentView(series: series)

            if canRead {
              HStack {
                Button {
                  continueReading()
                } label: {
                  Label(readLabel, systemImage: "play")
                }
                .adaptiveButtonStyle(.borderedProminent)
                .optimizedControlSize()

                Spacer()
              }
              .padding(.vertical, 8)
            }

            if let komgaSeries = komgaSeries {
              SeriesCollectionsSection(collectionIds: komgaSeries.collectionIds)
            }

            Divider()
            if let komgaSeries = komgaSeries {
              SeriesDownloadActionsSection(komgaSeries: komgaSeries)
            }
            Divider()
          }
          .padding(.horizontal)

          if komgaSeries != nil {
            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(navigationTitle)
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          seriesToolbarContent
        }
      }
    #endif
    .alert("Delete Series?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        deleteSeries()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(series?.metadata.title ?? "this series") from Komga.")
    }
    .sheet(isPresented: $showCollectionPicker) {
      CollectionPickerSheet(
        seriesId: seriesId,
        onSelect: { collectionId in
          addToCollection(collectionId: collectionId)
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
    .sheet(isPresented: $showSavedFilters) {
      SavedFiltersView(filterType: .seriesBooks)
    }
    .task {
      await refreshSeriesData()
    }
  }
}

extension SeriesDetailView {
  private func refreshSeriesData() async {
    do {
      // Sync from network to SwiftData (series property will update reactively)
      _ = try await SyncService.shared.syncSeriesDetail(seriesId: seriesId)
      await SyncService.shared.syncSeriesCollections(seriesId: seriesId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if komgaSeries == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
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

  private func continueReading() {
    Task {
      let book = await SeriesContinueReadingResolver.resolve(
        seriesId: seriesId,
        isOffline: isOffline,
        context: modelContext
      )
      if let book {
        readerPresentation.present(book: book, incognito: false)
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

  @ViewBuilder
  private var seriesToolbarContent: some View {
    HStack {
      Button {
        showSavedFilters = true
      } label: {
        Image(systemName: "bookmark")
      }

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      Menu {
        LayoutModePicker(selection: $seriesDetailLayout)

        Divider()

        if current.isAdmin {
          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
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
        }

        Divider()

        Button {
          showCollectionPicker = true
        } label: {
          Label("Add to Collection", systemImage: ContentIcon.collection)
        }

        if series != nil {
          if canMarkSeriesAsRead {
            Button {
              markSeriesAsRead()
            } label: {
              Label("Mark as Read", systemImage: "checkmark")
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

        if current.isAdmin {
          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Series", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
    }.toolbarButtonStyle()
  }
}
