//
//  ReadListsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListsBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @Environment(\.modelContext) private var modelContext
  @AppStorage("readListSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("readListBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
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
      ReadListSortView(showFilterSheet: $showFilterSheet)
        .padding(.horizontal)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.pagination.isEmpty,
        emptyIcon: ContentIcon.readList,
        emptyTitle: LocalizedStringKey("No read lists found"),
        emptyMessage: LocalizedStringKey("Try selecting a different library."),
        onRetry: {
          Task {
            await loadReadLists(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(viewModel.pagination.items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                layout: .grid
              )
              .padding(.bottom)
              .onAppear {
                if viewModel.pagination.shouldLoadMore(after: readList) {
                  Task {
                    await loadReadLists(refresh: false)
                  }
                }
              }
            }
          }
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(viewModel.pagination.items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                layout: .list
              )
              .onAppear {
                if viewModel.pagination.shouldLoadMore(after: readList) {
                  Task {
                    await loadReadLists(refresh: false)
                  }
                }
              }
              if !viewModel.pagination.isLast(readList) {
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
      await loadReadLists(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadReadLists(refresh: true)
      }
    }
    .onChange(of: sortOpts) { oldValue, newValue in
      if oldValue != newValue {
        Task {
          await loadReadLists(refresh: true)
        }
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadReadLists(refresh: true)
      }
    }
  }

  private func loadReadLists(refresh: Bool) async {
    await viewModel.load(
      refresh: refresh,
      offlineFetch: { offset, limit in
        KomgaReadListStore.fetchReadListIds(
          context: modelContext,
          libraryIds: libraryIds,
          searchText: searchText,
          sort: sortOpts.sortString,
          offset: offset,
          limit: limit
        )
      },
      onlineFetch: { page, size in
        let result = try await SyncService.shared.syncReadLists(
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
