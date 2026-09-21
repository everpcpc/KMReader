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

nonisolated extension ApiKey {
  /// Keys auto-created by KMReader as instance credentials carry this
  /// comment prefix and may be in active use.
  static let appManagedCommentPrefix = "KMReader · "

  /// Deterministic comment for the key this device auto-creates at login;
  /// used to re-identify the device's key when its id was never persisted.
  static func appManagedComment(deviceName: String) -> String {
    "\(appManagedCommentPrefix)\(deviceName)"
  }
}
