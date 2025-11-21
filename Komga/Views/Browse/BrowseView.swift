//
//  BrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BrowseView: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("seriesBrowseOptions") private var seriesBrowseOpts: SeriesBrowseOptions =
    SeriesBrowseOptions()
  @AppStorage("bookBrowseOptions") private var bookBrowseOpts: BookBrowseOptions =
    BookBrowseOptions()
  @AppStorage("browseContent") private var browseContent: BrowseContentType = .series
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @State private var showLibraryPickerSheet = false
  @State private var searchQuery: String = ""

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 0) {
            Picker("Content Type", selection: $browseContent) {
              ForEach(BrowseContentType.allCases) { type in
                Text(type.displayName).tag(type)
              }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            contentView(for: geometry.size)
          }
        }
        .handleNavigation()
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button {
              showLibraryPickerSheet = true
            } label: {
              Image(systemName: "books.vertical")
            }
          }
          ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
              Picker("Layout", selection: $browseLayout) {
                ForEach(BrowseLayoutMode.allCases) { mode in
                  Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
              }
              .pickerStyle(.inline)
            } label: {
              Image(systemName: browseLayout.iconName)
            }
          }
        }
        .sheet(isPresented: $showLibraryPickerSheet) {
          LibraryPickerSheet()
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic))
        .onChange(of: selectedLibraryId) { _, newValue in
          seriesBrowseOpts.libraryId = newValue
          bookBrowseOpts.libraryId = newValue
        }
        .onAppear {
          seriesBrowseOpts.libraryId = selectedLibraryId
          bookBrowseOpts.libraryId = selectedLibraryId
        }
      }
    }
  }

  @ViewBuilder
  private func contentView(for size: CGSize) -> some View {
    let searchText = searchQuery
    switch browseContent {
    case .series:
      SeriesBrowseView(
        browseOpts: $seriesBrowseOpts,
        width: size.width,
        height: size.height,
        searchText: searchText
      )
    case .books:
      BooksBrowseView(
        browseOpts: $bookBrowseOpts,
        width: size.width,
        height: size.height,
        searchText: searchText
      )
    case .collections:
      CollectionsBrowseView(
        browseOpts: $seriesBrowseOpts,
        width: size.width,
        height: size.height,
        searchText: searchText
      )
    case .readlists:
      ReadListsBrowseView(
        browseOpts: $seriesBrowseOpts,
        width: size.width,
        height: size.height,
        searchText: searchText
      )
    }
  }
}

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
    NavigationStack {
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
      .navigationTitle("Filter & Sort")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
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
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
    }
  }
}

struct LibraryPickerSheet: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Picker("Library", selection: $selectedLibraryId) {
          Label("All Libraries", systemImage: "square.grid.2x2").tag("")
          ForEach(LibraryManager.shared.libraries) { library in
            Label(library.name, systemImage: "books.vertical").tag(library.id)
          }
        }
        .pickerStyle(.inline)
      }
      .navigationTitle("Select Library")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
      .onChange(of: selectedLibraryId) { oldValue, newValue in
        // Dismiss when user selects a different library
        if oldValue != newValue {
          dismiss()
        }
      }
    }
  }
}
