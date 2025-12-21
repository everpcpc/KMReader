//
//  SimpleSortField.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum SimpleSortField: String, CaseIterable {
  case name = "name"
  case dateAdded = "createdDate"
  case dateUpdated = "lastModifiedDate"

  var displayName: String {
    switch self {
    case .name: return String(localized: "simpleSort.name")
    case .dateAdded: return String(localized: "simpleSort.dateAdded")
    case .dateUpdated: return String(localized: "simpleSort.dateUpdated")
    }
  }

  var supportsDirection: Bool {
    return true
  }
}
