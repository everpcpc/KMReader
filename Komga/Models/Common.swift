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
