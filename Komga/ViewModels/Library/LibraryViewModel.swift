//
//  LibraryViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

@MainActor
@Observable
class LibraryViewModel {
  var libraries: [Library] = []
  var isLoading = false
  var errorMessage: String?

  private let libraryService = LibraryService.shared

  func loadLibraries() async {
    isLoading = true
    errorMessage = nil

    do {
      libraries = try await libraryService.getLibraries()
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func scanLibrary(_ library: Library, deep: Bool = false) async throws {
    try await libraryService.scanLibrary(id: library.id, deep: deep)
  }

  func analyzeLibrary(_ library: Library) async throws {
    try await libraryService.analyzeLibrary(id: library.id)
  }

  func refreshMetadata(_ library: Library) async throws {
    try await libraryService.refreshMetadata(id: library.id)
  }

  func emptyTrash(_ library: Library) async throws {
    try await libraryService.emptyTrash(id: library.id)
  }

  func deleteLibrary(_ library: Library) async throws {
    try await libraryService.deleteLibrary(id: library.id)
  }
}
