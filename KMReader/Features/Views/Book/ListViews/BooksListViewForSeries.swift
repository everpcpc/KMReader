//
//  BooksListViewForSeries.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

// Books list view for series detail
struct BooksListViewForSeries: View {
  let seriesId: String
  @Bindable var bookViewModel: BookViewModel
  var onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("seriesDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("seriesBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        BookFilterView(
          browseOpts: $browseOpts,
          showFilterSheet: $showFilterSheet,
          layoutMode: $layoutMode
        )
      }

      SeriesBooksQueryView(
        seriesId: seriesId,
        bookViewModel: bookViewModel,
        onReadBook: onReadBook,
        layoutHelper: layoutHelper,
        browseLayout: layoutMode,
        refreshBooks: {
          refreshBooks()
        },
        loadMore: { refresh in
          await bookViewModel.loadSeriesBooks(
            context: modelContext,
            seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds,
            refresh: refresh)
        }
      )
    }
    .task(id: seriesId) {
      await bookViewModel.loadSeriesBooks(
        context: modelContext,
        seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds)
    }
    .onChange(of: browseOpts) {
      Task {
        await bookViewModel.loadSeriesBooks(
          context: modelContext,
          seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds)
      }
    }
  }
}

extension BooksListViewForSeries {
  fileprivate func refreshBooks() {
    Task {
      await bookViewModel.loadSeriesBooks(
        context: modelContext,
        seriesId: seriesId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds, refresh: false
      )
    }
  }
}
