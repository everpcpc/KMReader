//
//  LibraryService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class LibraryService {
  static let shared = LibraryService()
  private let apiClient = APIClient.shared

  private init() {}

  func getLibraries() async throws -> [Library] {
    return try await apiClient.request(path: "/api/v1/libraries")
  }

  func getLibrary(id: String) async throws -> Library {
    return try await apiClient.request(path: "/api/v1/libraries/\(id)")
  }
}
