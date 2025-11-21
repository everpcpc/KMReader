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

struct Media: Codable, Equatable {
  let status: String
  let mediaType: String
  let pagesCount: Int
  let comment: String?
  let mediaProfile: String?
  let epubDivinaCompatible: Bool?
  let epubIsKepub: Bool?
}

struct BookMetadata: Codable, Equatable {
  let created: String?
  let lastModified: String?
  let title: String
  let titleLock: Bool?
  let summary: String?
  let summaryLock: Bool?
  let number: String
  let numberLock: Bool?
  let numberSort: Double
  let numberSortLock: Bool?
  let releaseDate: String?
  let releaseDateLock: Bool?
  let authors: [Author]?
  let authorsLock: Bool?
  let tags: [String]?
  let tagsLock: Bool?
  let isbn: String?
  let isbnLock: Bool?
  let links: [WebLink]?
  let linksLock: Bool?
}

struct Author: Codable, Equatable, Hashable {
  let name: String
  let role: String
}

struct WebLink: Codable, Equatable {
  let label: String
  let url: String
}

struct ReadProgress: Codable, Equatable {
  let page: Int
  let completed: Bool
  let readDate: Date
  let created: Date
  let lastModified: Date
}

struct BookPage: Codable, Identifiable {
  let number: Int
  let fileName: String
  let mediaType: String
  let width: Int?
  let height: Int?
  let sizeBytes: Int64?
  let size: String

  var id: Int { number }

  /// Best-effort UTType detection using file extension first, then MIME type.
  var detectedUTType: UTType? {
    let fileExtension = (fileName as NSString).pathExtension.lowercased()
    if !fileExtension.isEmpty, let type = UTType(filenameExtension: fileExtension) {
      return type
    }

    let mimeType =
      mediaType.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
      ?? mediaType
    return UTType(mimeType: mimeType)
  }
}

// Sort field enum for Books
enum BookSortField: String, CaseIterable {
  case series = "series,metadata.numberSort"
  case name = "metadata.title"
  case dateAdded = "createdDate"
  case dateUpdated = "lastModifiedDate"
  case releaseDate = "metadata.releaseDate"
  case dateRead = "readProgress.readDate"
  case fileSize = "fileSize"
  case fileName = "name"
  case pageCount = "media.pagesCount"

  var displayName: String {
    switch self {
    case .series: return "Series"
    case .name: return "Name"
    case .dateAdded: return "Date Added"
    case .dateUpdated: return "Date Updated"
    case .releaseDate: return "Release Date"
    case .dateRead: return "Date Read"
    case .fileSize: return "File Size"
    case .fileName: return "File Name"
    case .pageCount: return "Page Count"
    }
  }

  var supportsDirection: Bool {
    return true
  }
}
