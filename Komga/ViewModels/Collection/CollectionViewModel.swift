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
  var collections: [Collection] = []
  var isLoading = false
  var errorMessage: String?

  private let collectionService = CollectionService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentLibraryId: String = ""
  private var currentSort: String?
  private var currentSearchText: String = ""

  func loadCollections(
    libraryId: String,
    sort: String?,
    searchText: String,
    refresh: Bool = false
  ) async {
    let paramsChanged = currentLibraryId != libraryId || currentSort != sort || currentSearchText != searchText
    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentLibraryId = libraryId
      currentSort = sort
      currentSearchText = searchText
    }

    guard hasMorePages && !isLoading else { return }

    isLoading = true
    errorMessage = nil

    do {
      let page = try await collectionService.getCollections(
        libraryId: libraryId,
        page: currentPage,
        size: 20,
        sort: sort,
        search: searchText.isEmpty ? nil : searchText)

      withAnimation {
        if shouldReset {
          collections = page.content
        } else {
          collections.append(contentsOf: page.content)
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
