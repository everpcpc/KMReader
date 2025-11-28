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

  private(set) var libraries: [LibraryInfo] = []
  private(set) var isLoading = false

  private let libraryService = LibraryService.shared
  private let libraryStore = KomgaLibraryStore.shared
  private var hasLoaded = false
  private var loadedInstanceId: String?

  func loadLibraries() async {
    guard let instanceId = AppConfig.currentInstanceId else {
      libraries = []
      hasLoaded = false
      loadedInstanceId = nil
      return
    }

    if loadedInstanceId != instanceId {
      loadPersistedLibraries(for: instanceId)
      loadedInstanceId = instanceId
      hasLoaded = false
    }

    guard !hasLoaded else { return }

    isLoading = true

    do {
      let fullLibraries = try await libraryService.getLibraries()
      // Extract only id and name
      let infos = fullLibraries.map { LibraryInfo(id: $0.id, name: $0.name) }
      libraries = infos
      try libraryStore.replaceLibraries(infos, for: instanceId)
      hasLoaded = true
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  func getLibrary(id: String) -> LibraryInfo? {
    return libraries.first { $0.id == id }
  }

  func refreshLibraries() async {
    hasLoaded = false
    await loadLibraries()
  }

  func clearAllLibraries() {
    libraries = []
    hasLoaded = false
    loadedInstanceId = nil
    do {
      try libraryStore.deleteLibraries(instanceId: nil)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func removeLibraries(for instanceId: String) {
    do {
      try libraryStore.deleteLibraries(instanceId: instanceId)
      if loadedInstanceId == instanceId {
        libraries = []
        hasLoaded = false
        loadedInstanceId = nil
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func loadPersistedLibraries(for instanceId: String) {
    libraries = libraryStore.fetchLibraries(instanceId: instanceId)
  }
}
