//
//  MetadataFilterConfig.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Configuration for metadata-based filtering
struct MetadataFilterConfig: Equatable {
  var publisher: String?
  var authors: [String]?
  var genres: [String]?
  var tags: [String]?

  init(
    publisher: String? = nil,
    authors: [String]? = nil,
    genres: [String]? = nil,
    tags: [String]? = nil
  ) {
    self.publisher = publisher
    self.authors = authors
    self.genres = genres
    self.tags = tags
  }

  /// Check if any filter is active
  var hasAnyFilter: Bool {
    return publisher != nil || authors != nil || genres != nil || tags != nil
  }

  /// Create config for publisher filter
  static func forPublisher(_ publisher: String) -> MetadataFilterConfig {
    return MetadataFilterConfig(publisher: publisher)
  }

  /// Create config for author filter
  static func forAuthor(_ author: String) -> MetadataFilterConfig {
    return MetadataFilterConfig(authors: [author])
  }

  /// Create config for authors filter
  static func forAuthors(_ authors: [String]) -> MetadataFilterConfig {
    return MetadataFilterConfig(authors: authors)
  }

  /// Create config for genre filter
  static func forGenre(_ genre: String) -> MetadataFilterConfig {
    return MetadataFilterConfig(genres: [genre])
  }

  /// Create config for genres filter
  static func forGenres(_ genres: [String]) -> MetadataFilterConfig {
    return MetadataFilterConfig(genres: genres)
  }

  /// Create config for tag filter
  static func forTag(_ tag: String) -> MetadataFilterConfig {
    return MetadataFilterConfig(tags: [tag])
  }

  /// Create config for tags filter
  static func forTags(_ tags: [String]) -> MetadataFilterConfig {
    return MetadataFilterConfig(tags: tags)
  }
}
