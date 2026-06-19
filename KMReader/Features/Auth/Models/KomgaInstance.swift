//
// KomgaInstance.swift
//

import Foundation

nonisolated struct KomgaInstance: Codable, Equatable, Sendable {
  var id: UUID
  var name: String
  var serverURL: String
  var username: String
  var authToken: String
  var isAdmin: Bool
  var authMethod: AuthenticationMethod?
  var protected: Bool
  var createdAt: Date
  var lastUsedAt: Date
  var seriesLastSyncedAt: Date
  var booksLastSyncedAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    serverURL: String,
    username: String,
    authToken: String,
    isAdmin: Bool,
    authMethod: AuthenticationMethod = .basicAuth,
    protected: Bool = false,
    createdAt: Date = Date(),
    lastUsedAt: Date = Date(),
    seriesLastSyncedAt: Date = Date(timeIntervalSince1970: 0),
    booksLastSyncedAt: Date = Date(timeIntervalSince1970: 0)
  ) {
    self.id = id
    self.name = name
    self.serverURL = serverURL
    self.username = username
    self.authToken = authToken
    self.isAdmin = isAdmin
    self.authMethod = authMethod
    self.protected = protected
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.seriesLastSyncedAt = seriesLastSyncedAt
    self.booksLastSyncedAt = booksLastSyncedAt
  }
}

nonisolated extension KomgaInstance {
  var displayName: String {
    name.isEmpty ? serverURL : name
  }

  var resolvedAuthMethod: AuthenticationMethod {
    authMethod ?? .basicAuth
  }
}
