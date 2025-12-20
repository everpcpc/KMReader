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
  var collections: [SeriesCollection] = []
  var isLoading = false

  private let collectionService = CollectionService.shared
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

    // 1. Local Cache
    let localCollections = KomgaCollectionStore.shared.fetchCollections(
      libraryIds: libraryIds,
      page: currentPage,
      size: 20,
      sort: sort,
      search: searchText.isEmpty ? nil : searchText
    )
    if !localCollections.isEmpty {
      if shouldReset {
        collections = localCollections
      } else {
        collections.append(contentsOf: localCollections)
      }
    }

    // 2. Sync
    do {
      let page = try await SyncService.shared.syncCollections(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20,
        sort: sort,
        search: searchText.isEmpty ? nil : searchText)

      withAnimation {
        if shouldReset {
          collections = page.content
        } else {
          // Merge logic
          if !localCollections.isEmpty {
            let startIndex = collections.count - localCollections.count
            if startIndex >= 0 {
              collections.replaceSubrange(startIndex..<collections.count, with: page.content)
            } else {
              collections.append(contentsOf: page.content)
            }
          } else {
            collections.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      if collections.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }
}
