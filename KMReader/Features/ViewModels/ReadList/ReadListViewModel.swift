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
  var isLoading = false

  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)

  func loadReadLists(
    context: ModelContext,
    libraryIds: [String]?,
    sort: String?,
    searchText: String,
    refresh: Bool = false
  ) async {
    if refresh {
      pagination.reset()
    } else {
      guard pagination.hasMorePages && !isLoading else { return }
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
      let ids = KomgaReadListStore.fetchReadListIds(
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
        let page = try await SyncService.shared.syncReadLists(
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
        if refresh {
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
