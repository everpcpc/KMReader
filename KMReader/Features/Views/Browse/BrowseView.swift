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
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var refreshTrigger = UUID()
  @State private var isRefreshDisabled = false
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var contentWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()
  @State private var showLibraryPicker = false
  @State private var showFilterSheet = false

  private let horizontalPadding: CGFloat = PlatformHelper.sheetPadding

  private func refreshBrowse() {
    refreshTrigger = UUID()
    isRefreshDisabled = true
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      isRefreshDisabled = false
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            Spacer()
            Picker("", selection: $browseContent) {
              ForEach(BrowseContentType.allCases) { type in
                Text(type.displayName).tag(type)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Spacer()
          }
          .padding(.horizontal, horizontalPadding)

          if contentWidth > 0 {
            contentView(layoutHelper: layoutHelper)
              .padding(.horizontal, horizontalPadding)
          }
        }
      }
      .handleNavigation()
      .inlineNavigationBarTitle(String(localized: "title.browse"))
      .searchable(text: $searchQuery)
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: "books.vertical")
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
      .onGeometryChange(for: CGSize.self) { geometry in
        geometry.size
      } action: { newSize in
        let newContentWidth = max(0, newSize.width - horizontalPadding * 2)
        if abs(contentWidth - newContentWidth) > 1 {
          contentWidth = newContentWidth
          layoutHelper = BrowseLayoutHelper(
            width: newContentWidth,
            browseColumns: browseColumns
          )
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
      .onChange(of: currentInstanceId) { _, _ in
        refreshBrowse()
      }
      .onChange(of: dashboard.libraryIds) { _, _ in
        refreshBrowse()
      }
      .onChange(of: readerPresentation.readerState == nil) { _, isReaderClosed in
        if isReaderClosed {
          refreshBrowse()
        }
      }
    }
  }

  @ViewBuilder
  private func contentView(layoutHelper: BrowseLayoutHelper) -> some View {
    switch browseContent {
    case .series:
      SeriesBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .books:
      BooksBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .collections:
      CollectionsBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    case .readlists:
      ReadListsBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger,
        showFilterSheet: $showFilterSheet
      )
    }
  }
}
