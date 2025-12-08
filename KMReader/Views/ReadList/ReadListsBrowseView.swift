//
//  ReadListsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

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

  var body: some View {
    VStack(spacing: 0) {
      ReadListSortView(showFilterSheet: $showFilterSheet, layoutMode: $browseLayout)
        .padding(layoutHelper.spacing)

      BrowseStateView(
        isLoading: viewModel.isLoading,
        isEmpty: viewModel.readLists.isEmpty,
        emptyIcon: "list.bullet.rectangle",
        emptyTitle: "No read lists found",
        emptyMessage: "Try selecting a different library.",
        onRetry: {
          Task {
            await loadReadLists(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.readLists.enumerated()), id: \.element.id) { index, readList in
              ReadListCardView(
                readList: readList,
                width: layoutHelper.cardWidth,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
              )
              .focusPadding()
              .onAppear {
                if index >= viewModel.readLists.count - 3 {
                  Task {
                    await loadReadLists(refresh: false)
                  }
                }
              }
            }
          }
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(viewModel.readLists.enumerated()), id: \.element.id) { index, readList in
              ReadListRowView(
                readList: readList,
                onActionCompleted: {
                  Task {
                    await loadReadLists(refresh: true)
                  }
                }
              )
              .onAppear {
                if index >= viewModel.readLists.count - 3 {
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
      if viewModel.readLists.isEmpty {
        await loadReadLists(refresh: true)
      }
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadReadLists(refresh: true)
      }
    }
    .onChange(of: sortOpts) { _, _ in
      Task {
        await loadReadLists(refresh: true)
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
      libraryIds: dashboard.libraryIds,
      sort: sortOpts.sortString,
      searchText: searchText,
      refresh: refresh
    )
  }
}
