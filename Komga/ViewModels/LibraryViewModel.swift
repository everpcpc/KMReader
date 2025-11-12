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
}
