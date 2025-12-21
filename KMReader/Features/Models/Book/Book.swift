//
//  Book.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import UniformTypeIdentifiers

struct Book: Codable, Identifiable, Equatable {
  let id: String
  let seriesId: String
  let seriesTitle: String
  let libraryId: String
  let name: String
  let url: String
  let number: Double
  let created: Date
  let lastModified: Date
  let sizeBytes: Int64
  let size: String
  let media: Media
  let metadata: BookMetadata
  let readProgress: ReadProgress?
  let deleted: Bool
  let oneshot: Bool
}
