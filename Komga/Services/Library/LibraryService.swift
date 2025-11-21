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

  func scanLibrary(id: String, deep: Bool = false) async throws {
    var queryItems: [URLQueryItem]? = nil
    if deep {
      queryItems = [URLQueryItem(name: "deep", value: "true")]
    }

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/scan",
      method: "POST",
      queryItems: queryItems
    )
  }

  func analyzeLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/analyze",
      method: "POST"
    )
  }

  func refreshMetadata(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/metadata/refresh",
      method: "POST"
    )
  }

  func emptyTrash(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/empty-trash",
      method: "POST"
    )
  }

  func deleteLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)",
      method: "DELETE"
    )
  }
}
