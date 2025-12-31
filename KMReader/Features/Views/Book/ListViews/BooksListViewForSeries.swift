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
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("seriesDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("seriesBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Button {
          Task {
            await refreshBooks(refresh: true)
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(bookViewModel.isLoading)
        .adaptiveButtonStyle(.bordered)
        .controlSize(.mini)

        Spacer()

        BookFilterView(
          browseOpts: $browseOpts,
          showFilterSheet: $showFilterSheet,
          layoutMode: $layoutMode
        )
      }
      .padding(.horizontal)

      SeriesBooksQueryView(
        seriesId: seriesId,
        bookViewModel: bookViewModel,
        layoutHelper: layoutHelper,
        browseLayout: layoutMode,
        refreshBooks: {
          Task {
            await refreshBooks(refresh: false)
          }
        },
        loadMore: { refresh in
          await refreshBooks(refresh: refresh)
        }
      )
    }
    .task(id: seriesId) {
      await refreshBooks(refresh: true)
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshBooks(refresh: true)
      }
    }
  }

  private func refreshBooks(refresh: Bool) async {
    await bookViewModel.loadSeriesBooks(
      context: modelContext,
      seriesId: seriesId,
      browseOpts: browseOpts,
      refresh: refresh
    )
  }
}
