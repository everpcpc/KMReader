//
// KomgaInstanceRecord.swift
//
//

import Foundation
import SQLiteData

@Table("komga_instances")
nonisolated struct KomgaInstanceRecord: Identifiable, Hashable, Sendable {
  let id: UUID
  var name: String
  var serverURL: String
  var username: String
  var authToken: String
  var isAdmin: Bool
  var authMethodRaw: String?
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdAt: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var lastUsedAt: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var seriesLastSyncedAt: Date
  @Column(as: Date.UnixTimeRepresentation.self)
  var booksLastSyncedAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    serverURL: String,
    username: String,
    authToken: String,
    isAdmin: Bool,
    authMethod: AuthenticationMethod = .basicAuth,
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
    self.authMethodRaw = authMethod.rawValue
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.seriesLastSyncedAt = seriesLastSyncedAt
    self.booksLastSyncedAt = booksLastSyncedAt
  }

  var displayName: String {
    name.isEmpty ? serverURL : name
  }

  var authMethod: AuthenticationMethod? {
    get {
      authMethodRaw.flatMap(AuthenticationMethod.init(rawValue:))
    }
    set {
      authMethodRaw = newValue?.rawValue
    }
  }

  var resolvedAuthMethod: AuthenticationMethod {
    authMethod ?? .basicAuth
  }

  func toKomgaInstance() -> KomgaInstance {
    KomgaInstance(
      id: id,
      name: name,
      serverURL: serverURL,
      username: username,
      authToken: authToken,
      isAdmin: isAdmin,
      authMethod: resolvedAuthMethod,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      seriesLastSyncedAt: seriesLastSyncedAt,
      booksLastSyncedAt: booksLastSyncedAt
    )
  }
}
