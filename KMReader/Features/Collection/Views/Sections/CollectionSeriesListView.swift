//
// CollectionSeriesListView.swift
//
//

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
  @State private var collectionItem: CollectionDisplayItem?

  init(
    collectionId: String,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>
  ) {
    self.collectionId = collectionId
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
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
            showSavedFilters: $showSavedFilters,
            collectionId: collectionId
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
          totalCount: collectionItem?.seriesCount ?? 0,
          isDeleting: isDeleting,
          onSelectAll: {
            if let seriesIds = collectionItem?.seriesIds {
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

      if collectionItem != nil {
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
    await loadCollection()
    await seriesViewModel.loadCollectionSeries(
      collectionId: collectionId,
      browseOpts: browseOpts,
      refresh: true
    )
  }

  private func loadCollection() async {
    guard let database = try? await DatabaseOperator.database() else {
      collectionItem = nil
      return
    }
    collectionItem = try? await database.fetchCollectionDisplayItem(
      collectionId: collectionId,
      instanceId: current.instanceId
    )
  }

  private func deleteSelectedSeries() async {
    guard !selectedSeriesIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await CollectionService.removeSeriesFromCollection(
        collectionId: collectionId,
        seriesIds: Array(selectedSeriesIds)
      )
      // Sync the collection to update its seriesIds in local SwiftData
      _ = try? await SyncService.syncCollection(id: collectionId)
      await loadCollection()

      ErrorManager.shared.notify(
        message: String(localized: "notification.series.removedFromCollection"))

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedSeriesIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the series list
      await refreshSeries()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
