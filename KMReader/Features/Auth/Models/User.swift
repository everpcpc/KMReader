//
//  User.swift
//  Komga
//
//

import Foundation

struct User: Codable {
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
