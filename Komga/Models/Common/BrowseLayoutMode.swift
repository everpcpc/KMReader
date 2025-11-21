//
//  BrowseLayoutMode.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum BrowseLayoutMode: String, CaseIterable, Identifiable {
  case grid
  case list

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .grid: return "Grid"
    case .list: return "List"
    }
  }

  var iconName: String {
    switch self {
    case .grid: return "square.grid.2x2"
    case .list: return "list.bullet"
    }
  }
}
