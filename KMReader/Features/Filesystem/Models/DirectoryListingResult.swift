//
// DirectoryListingResult.swift
//
//

import Foundation

/// Response from filesystem directory listing API
nonisolated struct DirectoryListingResult: Codable, Sendable {
  let parent: String?
  let directories: [PathItem]
  let files: [PathItem]
}

/// A path item representing a file or directory
nonisolated struct PathItem: Codable, Identifiable, Sendable {
  let type: String
  let name: String
  let path: String

  var id: String { path }

  var isDirectory: Bool { type == "directory" }
}
