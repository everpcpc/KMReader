//
//  AuthenticationActivity.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct AuthenticationActivity: Codable, Identifiable, Equatable {
  let id: UUID
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

  private enum CodingKeys: String, CodingKey {
    case userId
    case email
    case apiKeyId
    case apiKeyComment
    case ip
    case userAgent
    case success
    case error
    case dateTime
    case source
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = UUID()
    userId = try container.decode(String.self, forKey: .userId)
    email = try container.decode(String.self, forKey: .email)
    apiKeyId = try container.decodeIfPresent(String.self, forKey: .apiKeyId)
    apiKeyComment = try container.decodeIfPresent(String.self, forKey: .apiKeyComment)
    ip = try container.decodeIfPresent(String.self, forKey: .ip)
    userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
    success = try container.decode(Bool.self, forKey: .success)
    error = try container.decodeIfPresent(String.self, forKey: .error)
    dateTime = try container.decode(Date.self, forKey: .dateTime)
    source = try container.decodeIfPresent(String.self, forKey: .source)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(userId, forKey: .userId)
    try container.encode(email, forKey: .email)
    try container.encodeIfPresent(apiKeyId, forKey: .apiKeyId)
    try container.encodeIfPresent(apiKeyComment, forKey: .apiKeyComment)
    try container.encodeIfPresent(ip, forKey: .ip)
    try container.encodeIfPresent(userAgent, forKey: .userAgent)
    try container.encode(success, forKey: .success)
    try container.encodeIfPresent(error, forKey: .error)
    try container.encode(dateTime, forKey: .dateTime)
    try container.encodeIfPresent(source, forKey: .source)
  }

  static func == (lhs: AuthenticationActivity, rhs: AuthenticationActivity) -> Bool {
    lhs.userId == rhs.userId
      && lhs.email == rhs.email
      && lhs.apiKeyId == rhs.apiKeyId
      && lhs.apiKeyComment == rhs.apiKeyComment
      && lhs.ip == rhs.ip
      && lhs.userAgent == rhs.userAgent
      && lhs.success == rhs.success
      && lhs.error == rhs.error
      && lhs.dateTime == rhs.dateTime
      && lhs.source == rhs.source
  }
}
