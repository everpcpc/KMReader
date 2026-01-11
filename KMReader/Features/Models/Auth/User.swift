//
//  User.swift
//  Komga
//
//  Created by Komga iOS Client
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
