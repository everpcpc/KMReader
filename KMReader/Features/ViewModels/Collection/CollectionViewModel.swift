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
  var collectionIds: [String] = []
  var isLoading = false

  private let collectionService = CollectionService.shared
  private let pageSize = 50
  private var currentPage = 0
  private var hasMorePages = true
  private var currentLibraryIds: [String] = []
  private var currentSort: String?
  private var currentSearchText: String = ""
  private var currentLoadID = UUID()

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
      guard hasMorePages && !isLoading else { return }
    }

    if shouldReset {
      currentLoadID = UUID()
      currentPage = 0
      hasMorePages = true
      currentLibraryIds = libraryIds ?? []
      currentSort = sort
      currentSearchText = searchText
    }

    let loadID = currentLoadID
    isLoading = true

    defer {
      if loadID == currentLoadID {
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
        offset: currentPage * pageSize,
        limit: pageSize
      )
      guard loadID == currentLoadID else { return }
      updateState(ids: ids, moreAvailable: ids.count == pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncCollections(
          libraryIds: libraryIds,
          page: currentPage,
          size: pageSize,
          sort: sort,
          search: searchText.isEmpty ? nil : searchText
        )

        guard loadID == currentLoadID else { return }
        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == currentLoadID else { return }
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func updateState(ids: [String], moreAvailable: Bool) {
    withAnimation {
      if currentPage == 0 {
        collectionIds = ids
      } else {
        collectionIds.append(contentsOf: ids)
      }
    }
    hasMorePages = moreAvailable
    currentPage += 1
  }
}
