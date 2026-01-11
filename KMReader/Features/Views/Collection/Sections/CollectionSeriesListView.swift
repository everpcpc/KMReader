//
//  CollectionSeriesListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

// Series list view for collection
struct CollectionSeriesListView: View {
  let collectionId: String
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("collectionDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("collectionSeriesBrowseOptions") private var browseOpts: CollectionSeriesBrowseOptions =
    CollectionSeriesBrowseOptions()
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var seriesViewModel = SeriesViewModel()
  @State private var selectedSeriesIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false
  @Environment(\.modelContext) private var modelContext

  @Query private var collections: [KomgaCollection]

  private var collection: KomgaCollection? {
    collections.first
  }

  init(
    collectionId: String,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>
  ) {
    self.collectionId = collectionId
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters

    let compositeId = CompositeID.generate(id: collectionId)
    _collections = Query(filter: #Predicate<KomgaCollection> { $0.id == compositeId })
  }

  private var supportsSelectionMode: Bool {
    #if os(tvOS)
      return false
    #else
      return true
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Series")
          .font(.headline)

        Spacer()

        HStack(spacing: 8) {
          CollectionSeriesFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            showSavedFilters: $showSavedFilters
          )

          if supportsSelectionMode && !isSelectionMode && current.isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil")
            }
            .adaptiveButtonStyle(.borderedProminent)
            .optimizedControlSize()
            .transition(.opacity.combined(with: .scale))
          }
        }
      }
      .padding(.horizontal)

      if supportsSelectionMode && isSelectionMode {
        SelectionToolbar(
          selectedCount: selectedSeriesIds.count,
          totalCount: collection?.seriesIds.count ?? 0,
          isDeleting: isDeleting,
          onSelectAll: {
            if let seriesIds = collection?.seriesIds {
              if selectedSeriesIds.count == seriesIds.count {
                selectedSeriesIds.removeAll()
              } else {
                selectedSeriesIds = Set(seriesIds)
              }
            }
          },
          onDelete: {
            Task {
              await deleteSelectedSeries()
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedSeriesIds.removeAll()
          }
        )
        .padding(.horizontal)
      }

      if collection?.seriesIds != nil {
        CollectionSeriesQueryView(
          collectionId: collectionId,
          seriesViewModel: seriesViewModel,
          browseOpts: browseOpts,
          browseLayout: layoutMode,
          isSelectionMode: isSelectionMode,
          selectedSeriesIds: $selectedSeriesIds,
          isAdmin: current.isAdmin
        )
      } else if seriesViewModel.isLoading {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      }
    }
    .task(id: collectionId) {
      await refreshSeries()
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshSeries()
      }
    }
  }

  private func refreshSeries() async {
    await seriesViewModel.loadCollectionSeries(
      context: modelContext,
      collectionId: collectionId,
      browseOpts: browseOpts,
      refresh: true
    )
  }

  private func deleteSelectedSeries() async {
    guard !selectedSeriesIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await CollectionService.shared.removeSeriesFromCollection(
        collectionId: collectionId,
        seriesIds: Array(selectedSeriesIds)
      )
      // Sync the collection to update its seriesIds in local SwiftData
      _ = try? await SyncService.shared.syncCollection(id: collectionId)

      await MainActor.run {
        ErrorManager.shared.notify(
          message: String(localized: "notification.series.removedFromCollection"))
      }

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedSeriesIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the series list
      await refreshSeries()
    } catch {
      await MainActor.run {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
