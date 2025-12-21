//
//  AuthenticationActivity.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct AuthenticationActivity: Codable {
  let userId: String
  let email: String
  let apiKeyId: String?
  let apiKeyComment: String?
  let ip: String?
  let userAgent: String?
  let success: Bool
  let error: String?
  let dateTime: Date
  let source: String?
}
