//
//  CollectionViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class CollectionViewModel {
  var collectionIds: [String] { pagination.items.map(\.id) }
  var isLoading = false

  private let collectionService = CollectionService.shared
  private var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  private var currentLibraryIds: [String] = []
  private var currentSort: String?
  private var currentSearchText: String = ""

  func loadCollections(
    context: ModelContext,
    libraryIds: [String]?,
    sort: String?,
    searchText: String,
    refresh: Bool = false
  ) async {
    let paramsChanged =
      currentLibraryIds != libraryIds || currentSort != sort || currentSearchText != searchText
    let shouldReset = refresh || paramsChanged

    if !shouldReset {
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if shouldReset {
      pagination.reset()
      currentLibraryIds = libraryIds ?? []
      currentSort = sort
      currentSearchText = searchText
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let ids = KomgaCollectionStore.fetchCollectionIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        sort: sort,
        offset: pagination.currentPage * pagination.pageSize,
        limit: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncCollections(
          libraryIds: libraryIds,
          page: pagination.currentPage,
          size: pagination.pageSize,
          sort: sort,
          search: searchText.isEmpty ? nil : searchText
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }
}
