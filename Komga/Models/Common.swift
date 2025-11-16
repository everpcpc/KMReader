//
//  Common.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

/// Empty response for API calls that don't return data
struct EmptyResponse: Codable {}

/// Simplified library info containing only id and name
struct LibraryInfo: Identifiable, Codable, Equatable {
  let id: String
  let name: String
}

/// Sort direction for sorting operations
enum SortDirection: String, CaseIterable {
  case ascending = "asc"
  case descending = "desc"

  var displayName: String {
    switch self {
    case .ascending: return "Ascending"
    case .descending: return "Descending"
    }
  }

  var icon: String {
    switch self {
    case .ascending: return "arrow.up"
    case .descending: return "arrow.down"
    }
  }

  func toggle() -> SortDirection {
    return self == .ascending ? .descending : .ascending
  }
}
