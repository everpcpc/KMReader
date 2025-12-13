//
//  Author.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Author: Equatable, Hashable {
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
extension Author: Codable {
  enum CodingKeys: String, CodingKey {
    case name
    case role
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    let roleString = try container.decode(String.self, forKey: .role)
    role = AuthorRole(from: roleString)
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
