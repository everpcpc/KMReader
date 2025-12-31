//
//  BrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BrowseView: View {
  @AppStorage("browseContent") private var browseContent: BrowseContentType = .series
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()

  let library: KomgaLibrary?

  @State private var refreshTrigger = UUID()
  @State private var isRefreshDisabled = false
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var contentWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var showLibraryPicker = false
  @State private var showFilterSheet = false
  @State private var libraryIds: [String] = []

  init(library: KomgaLibrary? = nil) {
    self.library = library
  }

  var title: String {
    if let library = library {
      return library.name
    } else {
      return String(localized: "title.browse")
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

  func sectionCount(browseContent: BrowseContentType) -> Int? {
    guard let library = library else { return nil }
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
        if let library = library {
          VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: "books.vertical")
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

        if contentWidth > 0 {
          contentView()
        }
      }
    }
    .onContainerWidthChange { newWidth in
      contentWidth = newWidth
      layoutHelper = BrowseLayoutHelper(
        width: newWidth,
        browseColumns: browseColumns
      )
    }
    .inlineNavigationBarTitle(title)
    .animation(.default, value: library)
    .searchable(text: $searchQuery)
    #if !os(tvOS)
      .toolbar {
        if library == nil {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: "books.vertical.circle")
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            showFilterSheet = true
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
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
    .onChange(of: browseColumns) { _, _ in
      if contentWidth > 0 {
        layoutHelper = BrowseLayoutHelper(
          width: contentWidth,
          browseColumns: browseColumns
        )
      }
    }
    .onChange(of: authViewModel.isSwitching) { oldValue, newValue in
      guard library == nil else { return }
      // Refresh when server switch completes to avoid race condition
      if oldValue && !newValue {
        refreshBrowse()
      }
    }
    .onChange(of: library?.libraryId, initial: true) { oldValue, _ in
      if let library = library {
        libraryIds = [library.libraryId]
      } else {
        libraryIds = dashboard.libraryIds
      }
      // Skip refresh on initial load (oldValue is nil), .task handles that
      if oldValue != nil {
        refreshBrowse()
      }
    }
    .onChange(of: dashboard.libraryIds) { _, newValue in
      guard library == nil else { return }
      guard libraryIds != newValue else { return }
      libraryIds = newValue
      refreshBrowse()
    }
  }

  @ViewBuilder
  private func contentView() -> some View {
    switch browseContent {
    case .series:
      SeriesBrowseView(
        libraryIds: libraryIds,
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .books:
      BooksBrowseView(
        libraryIds: libraryIds,
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .collections:
      CollectionsBrowseView(
        libraryIds: libraryIds,
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .readlists:
      ReadListsBrowseView(
        libraryIds: libraryIds,
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    }
  }
}
