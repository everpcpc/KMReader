//
// Author.swift
//
//

import Foundation

nonisolated struct Author: Equatable, Hashable, Sendable {
  let name: String
  let role: AuthorRole

  init(name: String, role: AuthorRole) {
    self.name = name
    self.role = role
  }

  init(name: String, role: String) {
    self.name = name
    self.role = AuthorRole(from: role)
  }
}

// MARK: - Codable
nonisolated extension Author: Codable {
  enum CodingKeys: String, CodingKey {
    case name
    case role
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    role = AuthorRole(from: try container.decode(String.self, forKey: .role))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(role.rawValue, forKey: .role)
  }
}

// MARK: - Array Extension
extension Array where Element == Author {
  func sortedByRole() -> [Author] {
    sorted(by: { $0.role.sortOrder < $1.role.sortOrder })
  }
}
