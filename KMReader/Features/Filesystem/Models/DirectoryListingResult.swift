//
//  DirectoryListingResult.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Response from filesystem directory listing API
struct DirectoryListingResult: Codable {
  let parent: String?
  let directories: [PathItem]
  let files: [PathItem]
}

/// A path item representing a file or directory
struct PathItem: Codable, Identifiable {
  let type: String
  let name: String
  let path: String

  var id: String { path }

  var isDirectory: Bool { type == "directory" }
}
