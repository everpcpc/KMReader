//
//  ReadListViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
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
  private var currentLoadID = UUID()

  func loadReadLists(
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
      let ids = KomgaReadListStore.fetchReadListIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        sort: sort,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      guard loadID == currentLoadID else { return }
      let readLists = KomgaReadListStore.fetchReadListsByIds(
        context: context,
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
      do {
        let page = try await SyncService.shared.syncReadLists(
          libraryIds: libraryIds,
          page: currentPage,
          size: pageSize,
          sort: sort,
          search: searchText.isEmpty ? nil : searchText
        )

        guard loadID == currentLoadID else { return }
        let ids = page.content.map { $0.id }
        let readLists = KomgaReadListStore.fetchReadListsByIds(
          context: context,
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
        guard loadID == currentLoadID else { return }
        if shouldReset {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }
}
