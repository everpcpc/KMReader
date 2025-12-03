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

  @State private var refreshTrigger = UUID()
  @State private var isRefreshDisabled = false
  @State private var searchQuery: String = ""
  @State private var activeSearchText: String = ""
  @State private var contentWidth: CGFloat = 0
  @State private var layoutHelper = BrowseLayoutHelper()

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
      .inlineNavigationBarTitle("Browse")
      .searchable(text: $searchQuery)
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
    }
  }

  @ViewBuilder
  private func contentView(layoutHelper: BrowseLayoutHelper) -> some View {
    switch browseContent {
    case .series:
      SeriesBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger
      )
    case .books:
      BooksBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger
      )
    case .collections:
      CollectionsBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger
      )
    case .readlists:
      ReadListsBrowseView(
        layoutHelper: layoutHelper,
        searchText: activeSearchText,
        refreshTrigger: refreshTrigger
      )
    }
  }
}
