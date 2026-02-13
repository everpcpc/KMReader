//
//  CollectionsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct CollectionsBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @Environment(\.modelContext) private var modelContext
  @AppStorage("collectionSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("collectionBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @State private var viewModel = PaginatedIdViewModel()
  @State private var hasInitialized = false

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  var body: some View {
    VStack {
      CollectionSortView(showFilterSheet: $showFilterSheet)
        .padding(.horizontal)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.pagination.isEmpty,
        emptyIcon: ContentIcon.collection,
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
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(viewModel.pagination.items) { collection in
              CollectionQueryItemView(
                collectionId: collection.id
              )
              .padding(.bottom)
              .onAppear {
                if viewModel.pagination.shouldLoadMore(after: collection) {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
            }
          }
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(viewModel.pagination.items) { collection in
              CollectionQueryItemView(
                collectionId: collection.id,
                layout: .list
              )
              .onAppear {
                if viewModel.pagination.shouldLoadMore(after: collection) {
                  Task {
                    await loadCollections(refresh: false)
                  }
                }
              }
              if !viewModel.pagination.isLast(collection) {
                Divider()
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
    .task {
      guard !hasInitialized else { return }
      hasInitialized = true
      await loadCollections(refresh: true)
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
    await viewModel.load(
      refresh: refresh,
      offlineFetch: { offset, limit in
        KomgaCollectionStore.fetchCollectionIds(
          context: modelContext,
          libraryIds: libraryIds,
          searchText: searchText,
          sort: sortOpts.sortString,
          offset: offset,
          limit: limit
        )
      },
      onlineFetch: { page, size in
        let result = try await SyncService.shared.syncCollections(
          libraryIds: libraryIds,
          page: page,
          size: size,
          sort: sortOpts.sortString,
          search: searchText.isEmpty ? nil : searchText
        )
        return (ids: result.content.map { $0.id }, isLastPage: result.last)
      }
    )
  }
}
