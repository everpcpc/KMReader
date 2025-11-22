//
//  SeriesListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Series list view for collection
struct SeriesListView: View {
  let collectionId: String
  @Bindable var seriesViewModel: SeriesViewModel
  let layoutMode: BrowseLayoutMode
  let layoutHelper: BrowseLayoutHelper

  @AppStorage("collectionSeriesBrowseOptions") private var browseOpts: SeriesBrowseOptions =
    SeriesBrowseOptions()

  @State private var selectedSeriesIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Series")
          .font(.headline)

        Spacer()

        HStack(spacing: 8) {
          SeriesFilterView(browseOpts: $browseOpts)

          if !isSelectionMode && AppConfig.isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "checkmark.circle")
            }
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      if isSelectionMode {
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
            LazyVGrid(columns: layoutHelper.columns, spacing: 12) {
              ForEach(seriesViewModel.series) { series in
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
                .buttonStyle(.plain)
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
            .padding(12)
          case .list:
            LazyVStack(spacing: 8) {
              ForEach(seriesViewModel.series) { series in
                HStack(spacing: 12) {
                  if isSelectionMode {
                    Image(
                      systemName: selectedSeriesIds.contains(series.id)
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundColor(selectedSeriesIds.contains(series.id) ? .accentColor : .secondary)
                    .onTapGesture {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedSeriesIds.contains(series.id) {
                          selectedSeriesIds.remove(series.id)
                        } else {
                          selectedSeriesIds.insert(series.id)
                        }
                      }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(
                      .spring(response: 0.3, dampingFraction: 0.7),
                      value: selectedSeriesIds.contains(series.id))
                  }

                  if isSelectionMode {
                    SeriesRowView(
                      series: series,
                      onActionCompleted: {
                        Task {
                          await seriesViewModel.loadCollectionSeries(
                            collectionId: collectionId, browseOpts: browseOpts, refresh: true)
                        }
                      }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedSeriesIds.contains(series.id) {
                          selectedSeriesIds.remove(series.id)
                        } else {
                          selectedSeriesIds.insert(series.id)
                        }
                      }
                    }
                  } else {
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
                    .buttonStyle(.plain)
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

extension SeriesListView {
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

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedSeriesIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the series list
      await seriesViewModel.loadCollectionSeries(
        collectionId: collectionId, browseOpts: browseOpts, refresh: true)
    } catch {
      // Handle error if needed
    }
  }
}
