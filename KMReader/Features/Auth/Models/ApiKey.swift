//
// ApiKey.swift
//
//

import Foundation

nonisolated struct ApiKey: Codable, Identifiable, Hashable, Sendable {
  let id: String
  let userId: String
  let key: String  // This is probably a hint or prefix, strictly speaking the full key is only returned on creation
  let comment: String
  let createdDate: Date
  let lastModifiedDate: Date
}

nonisolated struct ApiKeyRequest: Codable, Sendable {
  let comment: String
}
