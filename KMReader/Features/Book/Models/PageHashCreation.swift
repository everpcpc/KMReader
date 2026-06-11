//
// PageHashCreation.swift
//
//

import Foundation

nonisolated struct PageHashCreation: Codable, Sendable {
  let hash: String
  let size: Int64?
  let action: PageHashAction
}
