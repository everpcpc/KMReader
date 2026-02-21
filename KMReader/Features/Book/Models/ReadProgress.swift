//
// ReadProgress.swift
//
//

import Foundation

nonisolated struct ReadProgress: Codable, Equatable, Hashable, Sendable {
  let page: Int
  let completed: Bool
  let readDate: Date
  let created: Date
  let lastModified: Date
}
