//
// ServerDisplayItem.swift
//
//

import Foundation

nonisolated struct ServerDisplayItem: Equatable, Identifiable, Sendable {
  let id: UUID
  let name: String
  let serverURL: String
  let username: String
  let authToken: String
  let isAdmin: Bool
  let authMethod: AuthenticationMethod
  let lastUsedAt: Date

  var instanceId: String {
    id.uuidString
  }

  var displayName: String {
    name.isEmpty ? serverURL : name
  }
}
