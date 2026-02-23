//
// ReadingStatsCache.swift
//
//

import Foundation

nonisolated struct ReadingStatsCache: Equatable, RawRepresentable, Sendable {
  typealias RawValue = String

  var snapshotsByScope: [String: ReadingStatsSnapshot]

  init(snapshotsByScope: [String: ReadingStatsSnapshot] = [:]) {
    self.snapshotsByScope = snapshotsByScope
  }

  func snapshot(instanceId: String, libraryId: String) -> ReadingStatsSnapshot? {
    snapshotsByScope[Self.scopeKey(instanceId: instanceId, libraryId: libraryId)]
  }

  mutating func upsert(snapshot: ReadingStatsSnapshot, instanceId: String, libraryId: String) {
    snapshotsByScope[Self.scopeKey(instanceId: instanceId, libraryId: libraryId)] = snapshot
  }

  mutating func clear(instanceId: String) {
    let prefix = "\(instanceId)|"
    snapshotsByScope = snapshotsByScope.filter { !$0.key.hasPrefix(prefix) }
  }

  static func scopeKey(instanceId: String, libraryId: String) -> String {
    let normalizedLibrary = libraryId.trimmingCharacters(in: .whitespacesAndNewlines)
    let libraryScope = normalizedLibrary.isEmpty ? "__all__" : normalizedLibrary
    return "\(instanceId)|\(libraryScope)"
  }

  var rawValue: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    guard
      let data = try? encoder.encode(snapshotsByScope),
      let json = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }

    return json
  }

  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8), !data.isEmpty else {
      self.snapshotsByScope = [:]
      return
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    if let decoded = try? decoder.decode([String: ReadingStatsSnapshot].self, from: data) {
      self.snapshotsByScope = decoded
    } else {
      self.snapshotsByScope = [:]
    }
  }
}
