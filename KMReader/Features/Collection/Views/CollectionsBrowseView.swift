//
// CollectionsBrowseView.swift
//
//

import SwiftUI

struct CollectionsBrowseView: View {
  let libraryIds: [String]
  let searchText: String
  let refreshTrigger: UUID
  @Binding var showFilterSheet: Bool

  @AppStorage("collectionSortOptions") private var sortOpts: SimpleSortOptions =
    SimpleSortOptions()
  @AppStorage("collectionBrowseLayout") private var browseLayout: BrowseLayoutMode = .grid
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
      CollectionSortView(showFilterSheet: $showFilterSheet)
        .padding(.horizontal)

      BrowseStateView(
        isLoading: isLoading,
        isEmpty: items.isEmpty,
        emptyIcon: ContentIcon.collection,
        emptyTitle: LocalizedStringKey("No collections found"),
        emptyMessage: LocalizedStringKey("Try selecting a different library."),
        onRetry: {
          Task {
            await loadCollections(refresh: true)
          }
        }
      ) {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { collection in
              CollectionQueryItemView(
                collectionId: collection.id
              )
              .padding(.bottom)
            }
          }
          .padding(.horizontal)
        case .list:
          LazyVStack {
            ForEach(items) { collection in
              CollectionQueryItemView(
                collectionId: collection.id,
                layout: .list
              )
              if items.last != collection {
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
      await loadCollections(refresh: true)
    }
    .onChange(of: refreshTrigger) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
    .onChange(of: sortOpts) { oldValue, newValue in
      if oldValue != newValue {
        Task {
          await loadCollections(refresh: true)
        }
      }
    }
    .onChange(of: searchText) { _, _ in
      Task {
        await loadCollections(refresh: true)
      }
    }
  }

  private func loadCollections(refresh: Bool) async {
    let currentLoadID = UUID()
    loadID = currentLoadID
    withAnimation {
      isLoading = true
    }

    do {
      let ids = try await loadCollectionIds()
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

  private func loadCollectionIds() async throws -> [String] {
    let localIds = await localCollectionIds()
    guard !AppConfig.isOffline else { return localIds }

    let serverIds = Set(try await syncCollectionIds())
    return localIds.filter { serverIds.contains($0) }
  }

  private func localCollectionIds() async -> [String] {
    guard !current.instanceId.isEmpty else { return [] }
    guard let database = try? await DatabaseOperator.database() else { return [] }
    return await database.fetchCollectionIds(
      instanceId: current.instanceId,
      libraryIds: libraryIds,
      searchText: searchText,
      sort: sortOpts.sortString,
      offset: 0,
      limit: Int.max
    )
  }

  private func syncCollectionIds() async throws -> [String] {
    var page = 0
    var ids: [String] = []

    while true {
      let result = try await SyncService.syncCollections(
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
