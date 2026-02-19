//
// ApiKey.swift
//
//

import Foundation

struct ApiKey: Codable, Identifiable, Hashable {
  let id: String
  let userId: String
  let key: String  // This is probably a hint or prefix, strictly speaking the full key is only returned on creation
  let comment: String
  let createdDate: Date
  let lastModifiedDate: Date
}

struct ApiKeyRequest: Codable {
  let comment: String
}
