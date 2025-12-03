//
//  BrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BrowseOptionsSheet: View {
  let contentType: BrowseContentType
  @Environment(\.dismiss) private var dismiss

  @Binding var seriesOpts: SeriesBrowseOptions?
  @Binding var bookOpts: BookBrowseOptions?

  @State private var tempSeriesOpts: SeriesBrowseOptions?
  @State private var tempBookOpts: BookBrowseOptions?

  init(browseOpts: Binding<SeriesBrowseOptions>, contentType: BrowseContentType) {
    self.contentType = contentType
    self._seriesOpts = Binding(
      get: { browseOpts.wrappedValue },
      set: { browseOpts.wrappedValue = $0 ?? SeriesBrowseOptions() }
    )
    self._bookOpts = Binding(
      get: { nil },
      set: { _ in }
    )
    self._tempSeriesOpts = State(initialValue: browseOpts.wrappedValue)
    self._tempBookOpts = State(initialValue: nil)
  }

  init(browseOpts: Binding<BookBrowseOptions>, contentType: BrowseContentType) {
    self.contentType = contentType
    self._seriesOpts = Binding(
      get: { nil },
      set: { _ in }
    )
    self._bookOpts = Binding(
      get: { browseOpts.wrappedValue },
      set: { browseOpts.wrappedValue = $0 ?? BookBrowseOptions() }
    )
    self._tempSeriesOpts = State(initialValue: nil)
    self._tempBookOpts = State(initialValue: browseOpts.wrappedValue)
  }

  var body: some View {
    SheetView(title: "Filter & Sort", size: .medium) {
        Form {
        if contentType.supportsReadStatusFilter || contentType.supportsSeriesStatusFilter {
          Section("Filters") {
            if contentType.supportsReadStatusFilter {
              if let tempSeriesOpts = tempSeriesOpts {
                Picker(
                  "Read Status",
                  selection: Binding(
                    get: { tempSeriesOpts.readStatusFilter },
                    set: { self.tempSeriesOpts?.readStatusFilter = $0 }
                  )
                ) {
                  ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                  }
                }
                .pickerStyle(.menu)
              } else if let tempBookOpts = tempBookOpts {
                Picker(
                  "Read Status",
                  selection: Binding(
                    get: { tempBookOpts.readStatusFilter },
                    set: { self.tempBookOpts?.readStatusFilter = $0 }
                  )
                ) {
                  ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                  }
                }
                .pickerStyle(.menu)
              }
            }

            if contentType.supportsSeriesStatusFilter, let tempSeriesOpts = tempSeriesOpts {
              Picker(
                "Series Status",
                selection: Binding(
                  get: { tempSeriesOpts.seriesStatusFilter },
                  set: { self.tempSeriesOpts?.seriesStatusFilter = $0 }
                )
              ) {
                ForEach(SeriesStatusFilter.allCases, id: \.self) { filter in
                  Text(filter.displayName).tag(filter)
                }
              }
              .pickerStyle(.menu)
            }
          }
        }

        if contentType.supportsSorting {
          Section("Sort") {
            if let tempSeriesOpts = tempSeriesOpts {
              Picker(
                "Sort By",
                selection: Binding(
                  get: { tempSeriesOpts.sortField },
                  set: { self.tempSeriesOpts?.sortField = $0 }
                )
              ) {
                ForEach(SeriesSortField.allCases, id: \.self) { field in
                  Text(field.displayName).tag(field)
                }
              }
              .pickerStyle(.menu)

              if tempSeriesOpts.sortField.supportsDirection {
                Picker(
                  "Direction",
                  selection: Binding(
                    get: { tempSeriesOpts.sortDirection },
                    set: { self.tempSeriesOpts?.sortDirection = $0 }
                  )
                ) {
                  ForEach(SortDirection.allCases, id: \.self) { direction in
                    HStack {
                      Image(systemName: direction.icon)
                      Text(direction.displayName)
                    }
                    .tag(direction)
                  }
                }
                .pickerStyle(.menu)
              }
            } else if let tempBookOpts = tempBookOpts {
              Picker(
                "Sort By",
                selection: Binding(
                  get: { tempBookOpts.sortField },
                  set: { self.tempBookOpts?.sortField = $0 }
                )
              ) {
                ForEach(BookSortField.allCases, id: \.self) { field in
                  Text(field.displayName).tag(field)
                }
              }
              .pickerStyle(.menu)

              if tempBookOpts.sortField.supportsDirection {
                Picker(
                  "Direction",
                  selection: Binding(
                    get: { tempBookOpts.sortDirection },
                    set: { self.tempBookOpts?.sortDirection = $0 }
                  )
                ) {
                  ForEach(SortDirection.allCases, id: \.self) { direction in
                    HStack {
                      Image(systemName: direction.icon)
                      Text(direction.displayName)
                    }
                    .tag(direction)
                  }
                }
                .pickerStyle(.menu)
              }
            }
          }
        }
        }
      }
    controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func applyChanges() {
    if let tempSeriesOpts = tempSeriesOpts, let seriesOpts = seriesOpts,
      tempSeriesOpts != seriesOpts
    {
      self.seriesOpts = tempSeriesOpts
    } else if let tempBookOpts = tempBookOpts, let bookOpts = bookOpts,
      tempBookOpts != bookOpts
    {
      self.bookOpts = tempBookOpts
    }
    dismiss()
  }
}
