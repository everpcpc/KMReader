//
//  BrowseContentType.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum BrowseContentType: String, CaseIterable, Identifiable {
  case series
  case books
  case collections
  case readlists

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .series: return "Series"
    case .books: return "Books"
    case .collections: return "Collections"
    case .readlists: return "Read Lists"
    }
  }

  var supportsReadStatusFilter: Bool {
    switch self {
    case .series, .books:
      return true
    case .collections, .readlists:
      return false
    }
  }

  var supportsSeriesStatusFilter: Bool {
    self == .series
  }

  var supportsSorting: Bool {
    switch self {
    case .series, .books:
      return true
    case .collections, .readlists:
      return false
    }
  }
}
