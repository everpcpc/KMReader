//
//  ReadListsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListsBrowseView: View {
  let layoutHelper: BrowseLayoutHelper
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("readListSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("readListBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var viewModel = ReadListViewModel()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      ReadListSortView(showFilterSheet: $showFilterSheet, layoutMode: $browseLayout)
        .padding(layoutHelper.spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.readListIds.isEmpty,
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
            ForEach(Array(viewModel.readListIds.enumerated()), id: \.element) {
              index, readListId in
              ReadListQueryItemView(
                readListId: readListId,
                width: layoutHelper.cardWidth,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.readListIds.count - 3 {
                  Task {
                    await loadReadLists(refresh: false)
                  }
                }
              }
            }
          }
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.readListIds.enumerated()), id: \.element) {
              index, readListId in
              ReadListQueryItemView(
                readListId: readListId,
                layout: .list,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.readListIds.count - 3 {
                  Task {
                    await loadReadLists(refresh: false)
                  }
                }
              }
            }
          }
        }
      }
    }
    .task {
      if viewModel.readListIds.isEmpty {
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
      libraryIds: dashboard.libraryIds,
      sort: sortOpts.sortString,
      searchText: searchText,
      refresh: refresh
    )
  }
}
