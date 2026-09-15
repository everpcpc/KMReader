//
// LibraryScopeLoader.swift
//
//

import SwiftUI

/// Shared loading for the library scope toolbar buttons. `refresh` hits the
/// server first; `load` only reads the local sidebar projection (used when the
/// projection changes notification fires).
enum LibraryScopeLoader {
  static func refresh(instanceId: String) async throws -> [SidebarLibraryItem] {
    await LibraryManager.shared.refreshLibraries()
    return try await load(instanceId: instanceId)
  }

  static func load(instanceId: String) async throws -> [SidebarLibraryItem] {
    guard !instanceId.isEmpty else {
      return []
    }
    let database = try await DatabaseOperator.database()
    return try await database.fetchSidebarLibraries(instanceId: instanceId)
  }
}
