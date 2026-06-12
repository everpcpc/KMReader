//
// SeriesDetailView.swift
//
//

import Flow
import SwiftUI

struct SeriesDetailView: View {
  let seriesId: String

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("seriesDetailLayout") private var seriesDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss
  @Environment(\.readerActions) private var readerActions

  @State private var item: SeriesDisplayItem?
  @State private var bookViewModel = BookViewModel()
  @State private var showDeleteConfirmation = false
  @State private var showCollectionPicker = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(seriesId: String) {
    self.seriesId = seriesId
  }

  private var series: Series? {
    item?.series
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

  private var shareURL: URL? {
    KomgaWebLinkBuilder.series(serverURL: current.serverURL, seriesId: seriesId)
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

            if let item {
              SeriesCollectionsSection(collectionIds: item.collectionIds)
            }

            Divider()
            if let item {
              SeriesDownloadActionsSection(
                seriesId: item.seriesId,
                status: item.downloadStatus,
                policy: item.offlinePolicy,
                offlinePolicyLimit: item.offlinePolicyLimit,
                onMutationCompleted: {
                  Task {
                    await refreshSeriesData()
                  }
                }
              )
            }
            Divider()
          }
          .padding(.horizontal)

          if item != nil {
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
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.series(serverURL: current.serverURL, seriesId: seriesId),
      scope: .browse
    )
    #if os(iOS) || os(macOS)
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
      _ = try await SyncService.syncSeriesDetail(seriesId: seriesId)
      await SyncService.syncSeriesCollections(seriesId: seriesId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if item == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
    await loadLocalSeries()
  }

  private func loadLocalSeries() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchSeriesDisplayItem(
      seriesId: seriesId,
      instanceId: current.instanceId
    )
  }

  private func analyzeSeries() {
    Task {
      do {
        try await SeriesService.analyzeSeries(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.analysisStarted"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func refreshSeriesMetadata() {
    Task {
      do {
        try await SeriesService.refreshMetadata(seriesId: seriesId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.metadataRefreshed"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsRead() {
    Task {
      do {
        try await SeriesService.markAsRead(seriesId: seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedRead"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func markSeriesAsUnread() {
    Task {
      do {
        try await SeriesService.markAsUnread(seriesId: seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.markedUnread"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func deleteSeries() {
    Task {
      do {
        try await SeriesService.deleteSeries(seriesId: seriesId)
        ErrorManager.shared.notify(message: String(localized: "notification.series.deleted"))
        dismiss()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func continueReading() {
    Task {
      let book = await SeriesContinueReadingResolver.resolve(
        seriesId: seriesId,
        instanceId: current.instanceId,
        isOffline: isOffline
      )
      if let book {
        readerActions.open(book: book, incognito: false)
      }
    }
  }

  private func addToCollection(collectionId: String) {
    Task {
      do {
        try await CollectionService.addSeriesToCollection(
          collectionId: collectionId,
          seriesIds: [seriesId]
        )
        // Sync the collection to update its seriesIds in local SwiftData
        _ = try? await SyncService.syncCollection(id: collectionId)
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.addedToCollection"))
        await refreshSeriesData()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  @ViewBuilder
  private var seriesToolbarContent: some View {
    HStack {
      #if os(iOS) || os(macOS)
        if let shareURL {
          ShareLink(item: shareURL, subject: Text(navigationTitle)) {
            Image(systemName: "square.and.arrow.up")
          }
        }
      #endif

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
