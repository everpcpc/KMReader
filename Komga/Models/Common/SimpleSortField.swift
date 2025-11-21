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
    case .name: return "Name"
    case .dateAdded: return "Date Added"
    case .dateUpdated: return "Date Updated"
    }
  }

  var supportsDirection: Bool {
    return true
  }
}
