//
//  CollectionSeriesListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Series list view for collection
struct CollectionSeriesListView: View {
  let collectionId: String
  @Bindable var seriesViewModel: SeriesViewModel
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("collectionDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("collectionSeriesBrowseOptions") private var browseOpts:
    CollectionSeriesBrowseOptions =
      CollectionSeriesBrowseOptions()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var selectedSeriesIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false

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
            layoutMode: $layoutMode
          )

          if supportsSelectionMode && !isSelectionMode && isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil.circle")
            }
            .adaptiveButtonStyle(.bordered)
            .controlSize(.small)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      if supportsSelectionMode && isSelectionMode {
        SelectionToolbar(
          selectedCount: selectedSeriesIds.count,
          totalCount: seriesViewModel.series.count,
          isDeleting: isDeleting,
          onSelectAll: {
            if selectedSeriesIds.count == seriesViewModel.series.count {
              selectedSeriesIds.removeAll()
            } else {
              selectedSeriesIds = Set(seriesViewModel.series.map { $0.id })
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
      }

      if seriesViewModel.isLoading && seriesViewModel.series.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        Group {
          switch layoutMode {
          case .grid:
            LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
              ForEach(seriesViewModel.series) { series in
                Group {
                  if supportsSelectionMode && isSelectionMode {
                    SeriesCardView(
                      series: series,
                      cardWidth: layoutHelper.cardWidth,
                      onActionCompleted: {
                        Task {
                          await seriesViewModel.loadCollectionSeries(
                            collectionId: collectionId, browseOpts: browseOpts, refresh: true)
                        }
                      }
                    )
                    .focusPadding()
                    .allowsHitTesting(false)
                    .overlay(alignment: .topTrailing) {
                      Image(
                        systemName: selectedSeriesIds.contains(series.id)
                          ? "checkmark.circle.fill" : "circle"
                      )
                      .foregroundColor(
                        selectedSeriesIds.contains(series.id) ? .accentColor : .secondary
                      )
                      .font(.title3)
                      .padding(8)
                      .background(
                        Circle()
                          .fill(.ultraThinMaterial)
                      )
                      .transition(.scale.combined(with: .opacity))
                      .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: selectedSeriesIds.contains(series.id))
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                      TapGesture()
                        .onEnded {
                          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedSeriesIds.contains(series.id) {
                              selectedSeriesIds.remove(series.id)
                            } else {
                              selectedSeriesIds.insert(series.id)
                            }
                          }
                        }
                    )
                  } else {
                    NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                      SeriesCardView(
                        series: series,
                        cardWidth: layoutHelper.cardWidth,
                        onActionCompleted: {
                          Task {
                            await seriesViewModel.loadCollectionSeries(
                              collectionId: collectionId, browseOpts: browseOpts, refresh: true)
                          }
                        }
                      )
                    }
                    .focusPadding()
                    .adaptiveButtonStyle(.plain)
                  }
                }
                .onAppear {
                  if series.id == seriesViewModel.series.last?.id {
                    Task {
                      await seriesViewModel.loadCollectionSeries(
                        collectionId: collectionId, browseOpts: browseOpts, refresh: false)
                    }
                  }
                }
              }
            }
            .padding(layoutHelper.spacing)
          case .list:
            LazyVStack(spacing: layoutHelper.spacing) {
              ForEach(seriesViewModel.series) { series in
                Group {
                  if supportsSelectionMode && isSelectionMode {
                    HStack(spacing: 12) {
                      Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                          if selectedSeriesIds.contains(series.id) {
                            selectedSeriesIds.remove(series.id)
                          } else {
                            selectedSeriesIds.insert(series.id)
                          }
                        }
                      } label: {
                        Image(
                          systemName: selectedSeriesIds.contains(series.id)
                            ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundColor(
                          selectedSeriesIds.contains(series.id) ? .accentColor : .secondary
                        )
                      }
                      .adaptiveButtonStyle(.plain)
                      .transition(.scale.combined(with: .opacity))
                      .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: selectedSeriesIds.contains(series.id))

                      SeriesRowView(
                        series: series,
                        onActionCompleted: {
                          Task {
                            await seriesViewModel.loadCollectionSeries(
                              collectionId: collectionId, browseOpts: browseOpts, refresh: true)
                          }
                        }
                      )
                      .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                      TapGesture()
                        .onEnded {
                          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedSeriesIds.contains(series.id) {
                              selectedSeriesIds.remove(series.id)
                            } else {
                              selectedSeriesIds.insert(series.id)
                            }
                          }
                        }
                    )
                  } else {
                    HStack(spacing: 12) {
                      NavigationLink(value: NavDestination.seriesDetail(seriesId: series.id)) {
                        SeriesRowView(
                          series: series,
                          onActionCompleted: {
                            Task {
                              await seriesViewModel.loadCollectionSeries(
                                collectionId: collectionId, browseOpts: browseOpts, refresh: true)
                            }
                          }
                        )
                      }
                      .adaptiveButtonStyle(.plain)
                    }
                  }
                }
                .onAppear {
                  if series.id == seriesViewModel.series.last?.id {
                    Task {
                      await seriesViewModel.loadCollectionSeries(
                        collectionId: collectionId, browseOpts: browseOpts, refresh: false)
                    }
                  }
                }
              }
            }
          }
        }

        if seriesViewModel.isLoading && !seriesViewModel.series.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
    }
    .task(id: collectionId) {
      await seriesViewModel.loadCollectionSeries(
        collectionId: collectionId, browseOpts: browseOpts, refresh: true)
    }
    .onChange(of: browseOpts) {
      Task {
        await seriesViewModel.loadCollectionSeries(
          collectionId: collectionId, browseOpts: browseOpts, refresh: true)
      }
    }
  }
}

extension CollectionSeriesListView {
  @MainActor
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
      await seriesViewModel.loadCollectionSeries(
        collectionId: collectionId, browseOpts: browseOpts, refresh: true)
    } catch {
      await MainActor.run {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
