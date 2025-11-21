//
//  BookBrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct BookBrowseOptions: Equatable, RawRepresentable {
  typealias RawValue = String

  var libraryId: String = ""
  var readStatusFilter: ReadStatusFilter = .all
  var sortField: BookSortField = .series
  var sortDirection: SortDirection = .ascending

  var sortString: String {
    return "\(sortField.rawValue),\(sortDirection.rawValue)"
  }

  var rawValue: String {
    let dict: [String: String] = [
      "libraryId": libraryId,
      "readStatusFilter": readStatusFilter.rawValue,
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
    self.sortField = BookSortField(rawValue: dict["sortField"] ?? "") ?? .series
    self.sortDirection = SortDirection(rawValue: dict["sortDirection"] ?? "") ?? .ascending
  }

  init() {}
}
