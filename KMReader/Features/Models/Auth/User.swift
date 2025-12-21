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
}
