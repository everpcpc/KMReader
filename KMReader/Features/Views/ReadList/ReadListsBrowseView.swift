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
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("readListSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("readListBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = ReadListViewModel()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      ReadListSortView(showFilterSheet: $showFilterSheet, layoutMode: $browseLayout)
        .padding(layoutHelper.spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.pagination.isEmpty,
        emptyIcon: "list.bullet.rectangle",
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
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(viewModel.pagination.items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                width: layoutHelper.cardWidth,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
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
          .padding(.horizontal, layoutHelper.spacing)
        case .list:
          LazyVStack {
            ForEach(viewModel.pagination.items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                layout: .list,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
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
      if viewModel.pagination.isEmpty {
        await loadReadLists(refresh: true)
      }
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
    await viewModel.loadReadLists(
      context: modelContext,
      libraryIds: libraryIds,
      sort: sortOpts.sortString,
      searchText: searchText,
      refresh: refresh
    )
  }
}
