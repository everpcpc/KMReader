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
  var readListIds: [String] = []
  var browseReadLists: [KomgaReadList] = []
  var isLoading = false

  var readLists: [ReadList] {
    browseReadLists.map { $0.toReadList() }
  }

  private let readListService = ReadListService.shared
  private let pageSize = 20
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

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = KomgaReadListStore.shared.fetchReadListIds(
        libraryIds: libraryIds,
        searchText: searchText,
        sort: sort,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      let readLists = KomgaReadListStore.shared.fetchReadListsByIds(
        ids: ids, instanceId: AppConfig.currentInstanceId)
      withAnimation {
        if currentPage == 0 {
          readListIds = ids
          browseReadLists = readLists
        } else {
          readListIds.append(contentsOf: ids)
          browseReadLists.append(contentsOf: readLists)
        }
      }
      hasMorePages = ids.count == pageSize
      currentPage += 1
    } else {
      // Online: fetch from API and sync
      do {
        let page = try await SyncService.shared.syncReadLists(
          libraryIds: libraryIds,
          page: currentPage,
          size: pageSize,
          sort: sort,
          search: searchText.isEmpty ? nil : searchText
        )

        let ids = page.content.map { $0.id }
        let readLists = KomgaReadListStore.shared.fetchReadListsByIds(
          ids: ids, instanceId: AppConfig.currentInstanceId)
        withAnimation {
          if currentPage == 0 {
            readListIds = ids
            browseReadLists = readLists
          } else {
            readListIds.append(contentsOf: ids)
            browseReadLists.append(contentsOf: readLists)
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
