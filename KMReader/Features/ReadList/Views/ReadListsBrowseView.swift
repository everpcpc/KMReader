//
// ReadListsBrowseView.swift
//
//

import SwiftUI

struct ReadListsBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("readListSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("readListBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var isLoading = false
  @State private var items: [IdentifiedString] = []
  @State private var loadID = UUID()
  @State private var hasInitialized = false

  private let syncPageSize = 200

  private var columns: [GridItem] {
    LayoutConfig.adaptiveColumns(for: gridDensity)
  }

  private var spacing: CGFloat {
    LayoutConfig.spacing(for: gridDensity)
  }

  var body: some View {
    VStack {
      ReadListSortView(showFilterSheet: $showFilterSheet)
        .padding(.horizontal)

      BrowseStateView(
        isLoading: isLoading,
        isEmpty: items.isEmpty,
        emptyIcon: ContentIcon.readList,
        emptyTitle: LocalizedStringKey("No read lists found"),
        emptyMessage: LocalizedStringKey("Try selecting a different library."),
        onRetry: {
          Task {
            await loadReadLists(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                layout: .grid
              )
              .padding(.bottom)
            }
          }
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(items) { readList in
              ReadListQueryItemView(
                readListId: readList.id,
                layout: .list
              )
              if items.last != readList {
                Divider()
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
    .task {
      guard !hasInitialized else { return }
      hasInitialized = true
      await loadReadLists(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadReadLists(refresh: true)
      }
    }
    .onChange(of: sortOpts) { oldValue, newValue in
      if oldValue != newValue {
        Task {
          await loadReadLists(refresh: true)
        }
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadReadLists(refresh: true)
      }
    }
  }

  private func loadReadLists(refresh: Bool) async {
    let currentLoadID = UUID()
    loadID = currentLoadID
    withAnimation {
      isLoading = true
    }

    do {
      let ids = try await loadReadListIds()
      guard loadID == currentLoadID else { return }
      withAnimation {
        items = ids.map(IdentifiedString.init)
      }
    } catch {
      guard loadID == currentLoadID else { return }
      if refresh {
        ErrorManager.shared.alert(error: error)
      }
    }

    guard loadID == currentLoadID else { return }
    withAnimation {
      isLoading = false
    }
  }

  private func loadReadListIds() async throws -> [String] {
    let localIds = await localReadListIds()
    guard !AppConfig.isOffline else { return localIds }

    let serverIds = Set(try await syncReadListIds())
    return localIds.filter { serverIds.contains($0) }
  }

  private func localReadListIds() async -> [String] {
    guard !current.instanceId.isEmpty else { return [] }
    guard let database = try? await DatabaseOperator.database() else { return [] }
    return await database.fetchReadListIds(
      instanceId: current.instanceId,
      libraryIds: libraryIds,
      searchText: searchText,
      sort: sortOpts.sortString,
      offset: 0,
      limit: Int.max
    )
  }

  private func syncReadListIds() async throws -> [String] {
    var page = 0
    var ids: [String] = []

    while true {
      let result = try await SyncService.syncReadLists(
        libraryIds: libraryIds,
        page: page,
        size: syncPageSize,
        sort: sortOpts.sortString,
        search: searchText.isEmpty ? nil : searchText
      )
      ids.append(contentsOf: result.content.map(\.id))
      guard !result.last else { break }
      page += 1
    }

    return ids
  }
}
