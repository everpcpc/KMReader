//
//  MetadataFilter.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

/// Represents metadata types that can be filtered
enum MetadataFilterType {
  case publisher(String)
  case author(String)
  case genre(String)
  case tag(String)

  var displayName: String {
    switch self {
    case .publisher(let value):
      return value
    case .author(let value):
      return value
    case .genre(let value):
      return value
    case .tag(let value):
      return value
    }
  }
}

/// Helper for navigating to browse view with metadata filters
struct MetadataFilterHelper {

  /// Get navigation destination for series browse with publisher filter
  static func seriesDestinationForPublisher(_ publisher: String) -> NavDestination {
    return .browseSeriesWithPublisher(publisher: publisher)
  }

  /// Get navigation destination for series browse with author filter
  static func seriesDestinationForAuthor(_ author: String) -> NavDestination {
    return .browseSeriesWithAuthor(author: author)
  }

  /// Get navigation destination for series browse with genre filter
  static func seriesDestinationForGenre(_ genre: String) -> NavDestination {
    return .browseSeriesWithGenre(genre: genre)
  }

  /// Get navigation destination for series browse with tag filter
  static func seriesDestinationForTag(_ tag: String) -> NavDestination {
    return .browseSeriesWithTag(tag: tag)
  }

  /// Get navigation destination for books browse with publisher filter (via series)
  static func booksDestinationForPublisher(_ publisher: String) -> NavDestination {
    return .browseSeriesWithPublisher(publisher: publisher)
  }

  /// Get navigation destination for books browse with author filter
  static func booksDestinationForAuthor(_ author: String) -> NavDestination {
    return .browseBooksWithAuthor(author: author)
  }

  /// Get navigation destination for books browse with tag filter
  static func booksDestinationForTag(_ tag: String) -> NavDestination {
    return .browseBooksWithTag(tag: tag)
  }
}
