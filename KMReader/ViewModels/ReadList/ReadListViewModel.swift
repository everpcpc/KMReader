//
//  ReadListViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class ReadListViewModel {
  var readLists: [ReadList] = []
  var isLoading = false

  private let readListService = ReadListService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentLibraryIds: [String] = []
  private var currentSort: String?
  private var currentSearchText: String = ""

  func loadReadLists(
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
    let localReadLists = KomgaReadListStore.shared.fetchReadLists(
      libraryIds: libraryIds,
      page: currentPage,
      size: 20,
      sort: sort,
      search: searchText.isEmpty ? nil : searchText
    )
    if !localReadLists.isEmpty {
      if shouldReset {
        readLists = localReadLists
      } else {
        readLists.append(contentsOf: localReadLists)
      }
    }

    // 2. Sync
    do {
      let page = try await SyncService.shared.syncReadLists(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20,
        sort: sort,
        search: searchText.isEmpty ? nil : searchText)

      withAnimation {
        if shouldReset {
          readLists = page.content
        } else {
          // Merge logic
          if !localReadLists.isEmpty {
            let startIndex = readLists.count - localReadLists.count
            if startIndex >= 0 {
              readLists.replaceSubrange(startIndex..<readLists.count, with: page.content)
            } else {
              readLists.append(contentsOf: page.content)
            }
          } else {
            readLists.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      if readLists.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }
}
