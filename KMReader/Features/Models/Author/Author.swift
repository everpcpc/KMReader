//
//  Author.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Author: Equatable, Hashable, Sendable {
  let name: String
  private let roleRaw: String

  var role: AuthorRole {
    AuthorRole(from: roleRaw)
  }

  init(name: String, role: AuthorRole) {
    self.name = name
    self.roleRaw = role.rawValue
  }

  init(name: String, role: String) {
    self.name = name
    self.roleRaw = role
  }
}

// MARK: - Codable
extension Author: Codable {
  enum CodingKeys: String, CodingKey {
    case name
    case roleRaw = "role"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    roleRaw = try container.decode(String.self, forKey: .roleRaw)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(roleRaw, forKey: .roleRaw)
  }
}

// MARK: - Array Extension
extension Array where Element == Author {
  func sortedByRole() -> [Author] {
    sorted(by: { $0.role.sortOrder < $1.role.sortOrder })
  }
}
