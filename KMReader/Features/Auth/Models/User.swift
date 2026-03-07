//
// User.swift
//
//

import Foundation

nonisolated struct User: Codable, Sendable {
  let id: String
  let email: String
  let roles: [String]

  var userRoles: [UserRole] {
    roles.map { UserRole(rawValue: $0) }
  }

  var isAdmin: Bool {
    roles.contains(UserRole.admin.rawValue)
  }
}
