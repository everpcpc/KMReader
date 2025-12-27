//
//  CollectionsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionsBrowseView: View {
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("collectionSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("collectionBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = CollectionViewModel()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      CollectionSortView(showFilterSheet: $showFilterSheet, layoutMode: $browseLayout)
        .padding()

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.collectionIds.isEmpty,
        emptyIcon: "square.grid.2x2",
        emptyTitle: LocalizedStringKey("No collections found"),
        emptyMessage: LocalizedStringKey("Try selecting a different library."),
        onRetry: {
          Task {
            await loadCollections(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.collectionIds.enumerated()), id: \.element) {
              index, collectionId in
              CollectionQueryItemView(
                collectionId: collectionId,
                width: layoutHelper.cardWidth,
                onActionCompleted: {
                  Task {
                    await loadCollections(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.collectionIds.count - 3 {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
            }
          }
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(Array(viewModel.collectionIds.enumerated()), id: \.element) {
              index, collectionId in
              CollectionQueryItemView(
                collectionId: collectionId,
                layout: .list,
                onActionCompleted: {
                  Task {
                    await loadCollections(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.collectionIds.count - 3 {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
              if index < viewModel.collectionIds.count - 1 {
                Divider()
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
    .task {
      if viewModel.collectionIds.isEmpty {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: sortOpts) { oldValue, newValue in
      if oldValue != newValue {
        Task {
          await loadCollections(refresh: true)
        }
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
      context: modelContext,
      libraryIds: dashboard.libraryIds,
      sort: sortOpts.sortString,
      searchText: searchText,
      refresh: refresh
    )
  }
}
