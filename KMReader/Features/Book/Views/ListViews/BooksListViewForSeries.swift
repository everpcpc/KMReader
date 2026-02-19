//
// BooksListViewForSeries.swift
//
//

import SwiftData
import SwiftUI

// Books list view for series detail
struct BooksListViewForSeries: View {
  let seriesId: String
  @Bindable var bookViewModel: BookViewModel
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

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
        .optimizedControlSize()

        Spacer()

        BookFilterView(
          browseOpts: $browseOpts,
          showFilterSheet: $showFilterSheet,
          showSavedFilters: $showSavedFilters,
          filterType: .seriesBooks,
          seriesId: seriesId
        )
      }
      .padding(.horizontal)

      SeriesBooksQueryView(
        seriesId: seriesId,
        bookViewModel: bookViewModel,
        browseOpts: browseOpts,
        browseLayout: layoutMode
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
