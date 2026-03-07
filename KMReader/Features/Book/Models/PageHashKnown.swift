//
// PageHashKnown.swift
//
//

import Foundation

nonisolated struct PageHashKnown: Codable, Identifiable, Equatable, Sendable {
  let hash: String
  let action: PageHashAction
  let matchCount: Int
  let deleteCount: Int
  let size: Int64?
  let created: Date
  let lastModified: Date

  var id: String { hash }
}
