//
//  BrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct BrowseOptions: Equatable, RawRepresentable {
  typealias RawValue = String

  var libraryId: String = ""
  var readStatusFilter: ReadStatusFilter = .all
  var seriesStatusFilter: SeriesStatusFilter = .all
  var sortField: SeriesSortField = .name
  var sortDirection: SortDirection = .ascending

  func sortString(for contentType: BrowseContentType) -> String? {
    switch contentType {
    case .series:
      return sortString
    case .books:
      return bookSortString
    case .collections:
      return collectionSortString
    case .readlists:
      return readListSortString
    }
  }

  var sortString: String {
    if sortField == .random {
      return "random"
    }
    return "\(sortField.rawValue),\(sortDirection.rawValue)"
  }

  var rawValue: String {
    let dict: [String: String] = [
      "libraryId": libraryId,
      "readStatusFilter": readStatusFilter.rawValue,
      "seriesStatusFilter": seriesStatusFilter.rawValue,
      "sortField": sortField.rawValue,
      "sortDirection": sortDirection.rawValue,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  init?(rawValue: String) {
    guard !rawValue.isEmpty else {
      return nil
    }
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else {
      return nil
    }
    self.libraryId = dict["libraryId"] ?? ""
    self.readStatusFilter = ReadStatusFilter(rawValue: dict["readStatusFilter"] ?? "") ?? .all
    self.seriesStatusFilter = SeriesStatusFilter(rawValue: dict["seriesStatusFilter"] ?? "") ?? .all
    self.sortField = SeriesSortField(rawValue: dict["sortField"] ?? "") ?? .name
    self.sortDirection = SortDirection(rawValue: dict["sortDirection"] ?? "") ?? .ascending
  }

  init() {}

  private var bookSortString: String? {
    switch sortField {
    case .name:
      return "metadata.title,\(sortDirection.rawValue)"
    case .dateAdded:
      return "createdDate,\(sortDirection.rawValue)"
    case .dateUpdated:
      return "lastModifiedDate,\(sortDirection.rawValue)"
    case .dateRead:
      return "readProgress.readDate,\(sortDirection.rawValue)"
    case .releaseDate:
      return "metadata.releaseDate,\(sortDirection.rawValue)"
    case .folderName:
      return "name,\(sortDirection.rawValue)"
    case .booksCount:
      return "media.pagesCount,\(sortDirection.rawValue)"
    case .random:
      return "random"
    }
  }

  private var collectionSortString: String? {
    switch sortField {
    case .name:
      return "name,\(sortDirection.rawValue)"
    case .dateAdded:
      return "createdDate,\(sortDirection.rawValue)"
    case .dateUpdated:
      return "lastModifiedDate,\(sortDirection.rawValue)"
    default:
      return nil
    }
  }

  private var readListSortString: String? {
    switch sortField {
    case .name:
      return "name,\(sortDirection.rawValue)"
    case .dateAdded:
      return "createdDate,\(sortDirection.rawValue)"
    case .dateUpdated, .dateRead:
      return "lastModifiedDate,\(sortDirection.rawValue)"
    default:
      return nil
    }
  }
}
