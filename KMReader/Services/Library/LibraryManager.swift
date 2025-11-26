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
  private var hasLoaded = false

  private init() {}

  func loadLibraries() async {
    // Only load once
    guard !hasLoaded else { return }

    isLoading = true

    do {
      let fullLibraries = try await libraryService.getLibraries()
      // Extract only id and name
      libraries = fullLibraries.map { LibraryInfo(id: $0.id, name: $0.name) }
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

  func clearLibraries() {
    libraries = []
    hasLoaded = false
  }
}
