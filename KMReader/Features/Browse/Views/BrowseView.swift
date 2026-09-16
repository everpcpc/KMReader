//
// BrowseView.swift
//
//

import SwiftUI

struct BrowseView: View {
  let authViewModel: AuthViewModel
  let fixedContent: BrowseContentType?
  let metadataFilter: MetadataFilterConfig?
  let focusesSearchOnAppear: Bool
  /// iPhone Library tab root mode: no navigation title, no search field, and
  /// no built-in toolbar library button (LibraryBrowseView adds its own with a
  /// scope label). The library scope is the global dashboard selection.
  let libraryTab: Bool
  /// Search-tab mode (iPhone): show a search placeholder until a query is
  /// entered instead of browsing all content.
  let searchOnly: Bool

  @Environment(\.browseLibrarySelection) private var librarySelection

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("browseContent") private var browseContent: BrowseContentType = .series
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  // Layout mode storage for each content type
  @AppStorage("seriesBrowseLayout") private var seriesBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("bookBrowseLayout") private var bookBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("collectionBrowseLayout") private var collectionBrowseLayout: BrowseLayoutMode = .grid
  @AppStorage("readListBrowseLayout") private var readListBrowseLayout: BrowseLayoutMode = .grid

  @State private var refreshTrigger = UUID()
  @State private var initializedLibraryIdsKey: String?
  @State private var isRefreshDisabled = false
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var showLibraryPicker = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false
  @State private var scopeLibraries: [SidebarLibraryItem] = []
  @FocusState private var isSearchFocused: Bool

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
    authViewModel: AuthViewModel,
    fixedContent: BrowseContentType? = nil,
    metadataFilter: MetadataFilterConfig? = nil,
    focusesSearchOnAppear: Bool = false,
    libraryTab: Bool = false,
    searchOnly: Bool = false
  ) {
    self.authViewModel = authViewModel
    self.fixedContent = fixedContent
    self.metadataFilter = metadataFilter
    self.focusesSearchOnAppear = focusesSearchOnAppear
    self.libraryTab = libraryTab
    self.searchOnly = searchOnly
  }

  var title: String {
    if libraryTab {
      return String(localized: "tab.library", defaultValue: "Library")
    } else if searchOnly {
      return String(localized: "tab.search", defaultValue: "Search")
    } else if let library = librarySelection {
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
    Group {
      if libraryTab {
        // iPhone Library tab: the toolbar scope button carries the context, no
        // nav title.
        mainContent
      } else if searchOnly {
        mainContent.tabRootNavigationBarTitle(title)
      } else {
        mainContent.inlineNavigationBarTitle(title)
      }
    }
  }

  private var mainContent: some View {
    ScrollView {
      VStack(spacing: 0) {
        if !libraryTab, let library = librarySelection {
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

        if fixedContent == nil && !(searchOnly && activeSearchText.isEmpty) {
          Picker("", selection: $browseContent) {
            ForEach(BrowseContentType.allCases) { type in
              Label(sectionTitle(browseContent: type), systemImage: type.icon)
                .labelStyle(.titleAndIcon)
                .tag(type)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .frame(maxWidth: .infinity)
          .padding(.horizontal)
          .padding(.vertical, 8)
        }

        if searchOnly && activeSearchText.isEmpty {
          ContentUnavailableView {
            Label(String(localized: "tab.search", defaultValue: "Search"), systemImage: "magnifyingglass")
          } description: {
            Text(
              String(
                localized: "search.empty.hint",
                defaultValue: "Search series, books, collections, and read lists."))
          }
          .frame(maxWidth: .infinity, minHeight: 320)
        } else {
          browseContentView
        }
      }
    }
    .searchableIfNeeded(text: $searchQuery, enabled: !libraryTab)
    .browseSearchFocus($isSearchFocused, when: focusesSearchOnAppear)
    .onAppear {
      // iPhone Search tab: entering the tab with an empty query activates the
      // search field directly.
      if searchOnly && searchQuery.isEmpty {
        isSearchFocused = true
      }
    }
    #if os(iOS) || os(macOS)
      .toolbar {
        if librarySelection == nil && !libraryTab && scopeLibraries.count > 1 {
          #if os(macOS)
            ToolbarItem(placement: .navigation) {
              LibraryScopeToolbarButton(libraries: scopeLibraries, isPresented: $showLibraryPicker)
            }
          #else
            ToolbarItem(placement: .cancellationAction) {
              LibraryScopeToolbarButton(libraries: scopeLibraries, isPresented: $showLibraryPicker)
            }
          #endif
        }

        ToolbarItem(placement: .confirmationAction) {
          Menu {
            Button {
              deferMenuActionPresentation { showFilterSheet = true }
            } label: {
              Label(String(localized: "Filter"), systemImage: "line.3.horizontal.decrease.circle")
            }

            if effectiveContent == .series || effectiveContent == .books {
              Button {
                deferMenuActionPresentation { showSavedFilters = true }
              } label: {
                Label(String(localized: "Saved Filters"), systemImage: "bookmark")
              }
            }

            LayoutModePicker(
              selection: layoutModeBinding,
              showGridDensity: true
            )
          } label: {
            Image(systemName: "ellipsis")
          }
        }
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
      .sheet(isPresented: $showSavedFilters) {
        SavedFiltersView(filterType: effectiveContent == .series ? .series : .books)
      }
      .task(id: current.instanceId) {
        await refreshScopeLibraries()
      }
      .onReceive(NotificationCenter.default.publisher(for: .sidebarProjectionDidChange)) { notification in
        guard notification.userInfo?["instanceId"] as? String == current.instanceId else { return }
        Task {
          await loadScopeLibraries()
        }
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
      guard initializedLibraryIdsKey != resolvedLibraryIdsKey else { return }
      initializedLibraryIdsKey = resolvedLibraryIdsKey
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

  private func refreshScopeLibraries() async {
    do {
      let loaded = try await LibraryScopeLoader.refresh(instanceId: current.instanceId)
      if scopeLibraries != loaded {
        scopeLibraries = loaded
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func loadScopeLibraries() async {
    do {
      let loaded = try await LibraryScopeLoader.load(instanceId: current.instanceId)
      if scopeLibraries != loaded {
        scopeLibraries = loaded
      }
    } catch {
      ErrorManager.shared.alert(error: error)
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
