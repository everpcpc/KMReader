//
// MetadataFilterItemSource.swift
//
//

import Foundation

enum MetadataFilterItemSource: Sendable {
  case publishers
  case authors(seriesId: String?, libraryIds: [String]?, collectionId: String?, readListId: String?)
  case genres(libraryIds: [String]?, collectionId: String?)
  case tags(seriesId: String?, readListId: String?, libraryIds: [String]?, collectionId: String?)
  case languages(libraryIds: [String]?, collectionId: String?)

  func load() async throws -> [String] {
    switch self {
    case .publishers:
      return try await ReferentialService.shared.getPublishers()
    case .authors(let seriesId, let libraryIds, let collectionId, let readListId):
      return try await ReferentialService.shared.getAuthorsNames(
        seriesId: seriesId,
        libraryIds: libraryIds,
        collectionId: collectionId,
        readListId: readListId
      )
    case .genres(let libraryIds, let collectionId):
      return try await ReferentialService.shared.getGenres(
        libraryIds: libraryIds,
        collectionId: collectionId
      )
    case .tags(let seriesId, let readListId, let libraryIds, let collectionId):
      if seriesId != nil || readListId != nil {
        return try await ReferentialService.shared.getBookTags(
          seriesId: seriesId,
          readListId: readListId,
          libraryIds: libraryIds
        )
      }
      return try await ReferentialService.shared.getTags(
        libraryIds: libraryIds,
        collectionId: collectionId
      )
    case .languages(let libraryIds, let collectionId):
      return try await ReferentialService.shared.getLanguages(
        libraryIds: libraryIds,
        collectionId: collectionId
      )
    }
  }
}
