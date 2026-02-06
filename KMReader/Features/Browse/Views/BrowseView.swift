//
//  BrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BrowseView: View {
  let fixedContent: BrowseContentType?
  let metadataFilter: MetadataFilterConfig?

  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(\.browseLibrarySelection) private var librarySelection

  @AppStorage("browseContent") private var browseContent: BrowseContentType = .series
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  // Layout mode storage for each content type
  @AppStorage("seriesBrowseLayout") private var seriesBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("bookBrowseLayout") private var bookBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("collectionBrowseLayout") private var collectionBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("readListBrowseLayout") private var readListBrowseLayout: BrowseLayoutMode = .grid

  @State private var refreshTrigger = UUID()
  @State private var isRefreshDisabled = false
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var showLibraryPicker = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  private var effectiveContent: BrowseContentType {
    fixedContent ?? browseContent
  }

  // Computed binding that routes to the correct layout mode based on content type
  private var layoutModeBinding: Binding<BrowseLayoutMode> {
    switch effectiveContent {
    case .series:
      return $seriesBrowseLayout
    case .books:
      return $bookBrowseLayout
    case .collections:
      return $collectionBrowseLayout
    case .readlists:
      return $readListBrowseLayout
    }
  }

  init(
    fixedContent: BrowseContentType? = nil,
    metadataFilter: MetadataFilterConfig? = nil
  ) {
    self.fixedContent = fixedContent
    self.metadataFilter = metadataFilter
  }

  var title: String {
    if let library = librarySelection {
      return library.name
    } else if let fixedContent {
      return fixedContent.displayName
    } else {
      return String(localized: "title.browse")
    }
  }

  private var resolvedLibraryIds: [String] {
    if let library = librarySelection {
      return [library.libraryId]
    }
    return dashboard.libraryIds
  }

  private var resolvedLibraryIdsKey: String {
    resolvedLibraryIds.joined(separator: ",")
  }

  private var gridDensityBinding: Binding<GridDensity> {
    Binding(
      get: { GridDensity.closest(to: gridDensity) },
      set: { gridDensity = $0.rawValue }
    )
  }

  func sectionCount(browseContent: BrowseContentType) -> Int? {
    guard let library = librarySelection else { return nil }
    switch browseContent {
    case .series:
      return library.seriesCount.map { Int($0) }
    case .books:
      return library.booksCount.map { Int($0) }
    case .collections:
      return library.collectionsCount.map { Int($0) }
    case .readlists:
      return library.readlistsCount.map { Int($0) }
    }
  }

  func sectionTitle(browseContent: BrowseContentType) -> String {
    if let count = sectionCount(browseContent: browseContent) {
      return String(format: "%@ (%d)", browseContent.displayName, count)
    }
    return browseContent.displayName
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if let library = librarySelection {
          VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: ContentIcon.library)
              Text(library.name)
                .font(.title2)
              if let fileSize = library.fileSize {
                Text(fileSize.humanReadableFileSize)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              Spacer()
            }
          }.padding()
        }

        if fixedContent == nil {
          HStack {
            Spacer()
            Picker("", selection: $browseContent) {
              ForEach(BrowseContentType.allCases) { type in
                Text(sectionTitle(browseContent: type)).tag(type)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Spacer()
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
        }

        browseContentView
      }
    }
    .inlineNavigationBarTitle(title)
    .animation(.default, value: librarySelection)
    .searchable(text: $searchQuery)
    #if !os(tvOS)
      .toolbar {
        if librarySelection == nil {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: ContentIcon.library)
            }
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          HStack {
            if effectiveContent == .series || effectiveContent == .books {
              Button {
                showSavedFilters = true
              } label: {
                Image(systemName: "bookmark")
              }
            }

            Button {
              showFilterSheet = true
            } label: {
              Image(systemName: "line.3.horizontal.decrease.circle")
            }

            Menu {
              LayoutModePicker(
                selection: layoutModeBinding,
                showGridDensity: true
              )
            } label: {
              Image(systemName: "ellipsis")
            }
            .appMenuStyle()
          }
        }
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
      .sheet(isPresented: $showSavedFilters) {
        SavedFiltersView(filterType: effectiveContent == .series ? .series : .books)
      }
    #endif
    .onSubmit(of: .search) {
      activeSearchText = searchQuery
    }
    .onChange(of: searchQuery) { _, newValue in
      if newValue.isEmpty {
        activeSearchText = ""
      }
    }
    .onChange(of: authViewModel.isSwitching) { oldValue, newValue in
      guard librarySelection == nil else { return }
      // Refresh when server switch completes to avoid race condition
      if oldValue && !newValue {
        refreshBrowse()
      }
    }
    .task(id: resolvedLibraryIdsKey) {
      guard !authViewModel.isSwitching else { return }
      refreshBrowse()
    }
  }

  private func refreshBrowse() {
    refreshTrigger = UUID()
    isRefreshDisabled = true
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      isRefreshDisabled = false
    }
  }

  @ViewBuilder
  private var browseContentView: some View {
    switch effectiveContent {
    case .series:
      SeriesBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        metadataFilter: metadataFilter,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
      )
    case .books:
      BooksBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        metadataFilter: metadataFilter,
        showFilterSheet: $showFilterSheet,
        showSavedFilters: $showSavedFilters,
      )
    case .collections:
      CollectionsBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .readlists:
      ReadListsBrowseView(
        libraryIds: resolvedLibraryIds,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    }
  }
}
