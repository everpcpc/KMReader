//
//  SimpleSortOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct SimpleSortOptions: Equatable, RawRepresentable {
  typealias RawValue = String

  var sortField: SimpleSortField = .name
  var sortDirection: SortDirection = .ascending

  var sortString: String {
    "\(sortField.rawValue),\(sortDirection.rawValue)"
  }

  var rawValue: String {
    let dict: [String: String] = [
      "sortField": sortField.rawValue,
      "sortDirection": sortDirection.rawValue,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
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
    self.sortField = SimpleSortField(rawValue: dict["sortField"] ?? "") ?? .name
    self.sortDirection = SortDirection(rawValue: dict["sortDirection"] ?? "") ?? .ascending
  }

  init() {}
}
