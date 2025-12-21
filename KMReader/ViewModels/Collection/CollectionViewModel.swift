//
//  CollectionViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class CollectionViewModel {
  var collectionIds: [String] = []
  var browseCollections: [KomgaCollection] = []
  var isLoading = false

  var collections: [SeriesCollection] {
    browseCollections.map { $0.toCollection() }
  }

  private let collectionService = CollectionService.shared
  private let pageSize = 20
  private var currentPage = 0
  private var hasMorePages = true
  private var currentLibraryIds: [String] = []
  private var currentSort: String?
  private var currentSearchText: String = ""

  func loadCollections(
    libraryIds: [String]?,
    sort: String?,
    searchText: String,
    refresh: Bool = false
  ) async {
    let paramsChanged =
      currentLibraryIds != libraryIds || currentSort != sort || currentSearchText != searchText
    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentLibraryIds = libraryIds ?? []
      currentSort = sort
      currentSearchText = searchText
    }

    guard hasMorePages && !isLoading else { return }

    isLoading = true

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = KomgaCollectionStore.shared.fetchCollectionIds(
        libraryIds: libraryIds,
        searchText: searchText,
        sort: sort,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      let collections = KomgaCollectionStore.shared.fetchCollectionsByIds(
        ids: ids, instanceId: AppConfig.currentInstanceId)
      withAnimation {
        if currentPage == 0 {
          collectionIds = ids
          browseCollections = collections
        } else {
          collectionIds.append(contentsOf: ids)
          browseCollections.append(contentsOf: collections)
        }
      }
      hasMorePages = ids.count == pageSize
      currentPage += 1
    } else {
      // Online: fetch from API and sync
      do {
        let page = try await SyncService.shared.syncCollections(
          libraryIds: libraryIds,
          page: currentPage,
          size: pageSize,
          sort: sort,
          search: searchText.isEmpty ? nil : searchText
        )

        let ids = page.content.map { $0.id }
        let collections = KomgaCollectionStore.shared.fetchCollectionsByIds(
          ids: ids, instanceId: AppConfig.currentInstanceId)
        withAnimation {
          if currentPage == 0 {
            collectionIds = ids
            browseCollections = collections
          } else {
            collectionIds.append(contentsOf: ids)
            browseCollections.append(contentsOf: collections)
          }
        }
        hasMorePages = !page.last
        currentPage += 1
      } catch {
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
    }

    withAnimation {
      isLoading = false
    }
  }
}
