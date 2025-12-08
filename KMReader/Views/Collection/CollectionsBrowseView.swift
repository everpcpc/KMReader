//
//  CollectionsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct CollectionsBrowseView: View {
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  private let spacing: CGFloat = 12

  @AppStorage("collectionSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("collectionBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = CollectionViewModel()

  var body: some View {
    VStack(spacing: 0) {
      CollectionSortView(showFilterSheet: $showFilterSheet, layoutMode: $browseLayout)
        .padding(spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.collections.isEmpty,
        emptyIcon: "square.grid.2x2",
        emptyTitle: "No collections found",
        emptyMessage: "Try selecting a different library.",
        onRetry: {
          Task {
            await loadCollections(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: spacing) {
            ForEach(Array(viewModel.collections.enumerated()), id: \.element.id) {
              index, collection in
              CollectionCardView(
                collection: collection,
                width: layoutHelper.cardWidth,
                onActionCompleted: {
                  Task {
                    await loadCollections(refresh: true)
                  }
                }
              )
              .focusPadding()
              .onAppear {
                if index >= viewModel.collections.count - 3 {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
            }
          }
        case .list:
          LazyVStack(spacing: spacing) {
            ForEach(Array(viewModel.collections.enumerated()), id: \.element.id) {
              index, collection in
              CollectionRowView(
                collection: collection,
                onActionCompleted: {
                  Task {
                    await loadCollections(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.collections.count - 3 {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
            }
          }
        }
      }
    }
    .task {
      if viewModel.collections.isEmpty {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: sortOpts) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
  }

  private func loadCollections(refresh: Bool) async {
    await viewModel.loadCollections(
      libraryIds: dashboard.libraryIds,
      sort: sortOpts.sortString,
      searchText: searchText,
      refresh: refresh
    )
  }
}
