//
//  LibraryManager.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

@MainActor
@Observable
class LibraryManager {
  static let shared = LibraryManager()

  private(set) var isLoading = false

  private let libraryService = LibraryService.shared
  private var hasLoaded = false
  private var loadedInstanceId: String?

  func loadLibraries() async {
    let instanceId = AppConfig.currentInstanceId
    guard !instanceId.isEmpty else {
      hasLoaded = false
      loadedInstanceId = nil
      return
    }

    if loadedInstanceId != instanceId {
      loadedInstanceId = instanceId
      hasLoaded = false
    }

    guard !hasLoaded else { return }

    isLoading = true

    do {
      let fullLibraries = try await libraryService.getLibraries()
      let infos = fullLibraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      try await DatabaseOperator.shared.replaceLibraries(infos, for: instanceId)
      await DatabaseOperator.shared.commit()
      hasLoaded = true
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  func getLibrary(id: String) async -> LibraryInfo? {
    let instanceId = AppConfig.currentInstanceId
    guard !instanceId.isEmpty else {
      return nil
    }
    let libraries = await DatabaseOperator.shared.fetchLibraries(instanceId: instanceId)
    return libraries.first { $0.id == id }
  }

  func refreshLibraries() async {
    hasLoaded = false
    await loadLibraries()
  }

  func removeLibraries(for instanceId: String) {
    Task {
      do {
        try await DatabaseOperator.shared.deleteLibraries(instanceId: instanceId)
        if loadedInstanceId == instanceId {
          hasLoaded = false
          loadedInstanceId = nil
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
