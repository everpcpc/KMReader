//
//  FilesystemService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

class FilesystemService {
  static let shared = FilesystemService()
  private let apiClient = APIClient.shared

  private init() {}

  /// Get directory listing from the server
  /// - Parameters:
  ///   - path: The directory path to list (empty for root)
  ///   - showFiles: Whether to include files in the listing
  /// - Returns: The directory listing result
  func getDirectoryListing(path: String = "", showFiles: Bool = false) async throws
    -> DirectoryListingResult
  {
    struct RequestBody: Codable {
      let path: String
      let showFiles: Bool
    }

    let body = RequestBody(path: path, showFiles: showFiles)
    let bodyData = try JSONEncoder().encode(body)

    return try await apiClient.request(
      path: "/api/v1/filesystem",
      method: "POST",
      body: bodyData
    )
  }
}
