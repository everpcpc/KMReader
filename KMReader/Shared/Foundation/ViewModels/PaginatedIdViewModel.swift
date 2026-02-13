//
//  PaginatedIdViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class PaginatedIdViewModel {
  var isLoading = false
  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)

  func load(
    refresh: Bool = false,
    offlineFetch: (_ offset: Int, _ limit: Int) -> [String],
    onlineFetch: (_ page: Int, _ size: Int) async throws -> (ids: [String], isLastPage: Bool)
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
      let ids = offlineFetch(
        pagination.currentPage * pagination.pageSize,
        pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let result = try await onlineFetch(pagination.currentPage, pagination.pageSize)
        guard loadID == pagination.loadID else { return }
        applyPage(ids: result.ids, moreAvailable: !result.isLastPage)
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
