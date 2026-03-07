//
// PageHashUnknown.swift
//
//

import Foundation

nonisolated struct PageHashUnknown: Codable, Identifiable, Equatable, Sendable {
  let hash: String
  let matchCount: Int
  let size: Int64?

  var id: String { hash }
}
