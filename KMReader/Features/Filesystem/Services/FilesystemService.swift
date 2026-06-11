//
// FilesystemService.swift
//
//

import Foundation

nonisolated enum FilesystemService {
  private static let apiClient = APIClient.shared

  /// Get directory listing from the server
  /// - Parameters:
  ///   - path: The directory path to list (empty for root)
  ///   - showFiles: Whether to include files in the listing
  /// - Returns: The directory listing result
  static func getDirectoryListing(path: String = "", showFiles: Bool = false) async throws
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
