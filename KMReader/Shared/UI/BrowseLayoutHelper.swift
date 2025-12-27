//
//  BrowseLayoutHelper.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Helper for calculating browse layout dimensions
struct BrowseLayoutHelper {
  let width: CGFloat
  let spacing: CGFloat
  let browseColumns: BrowseColumns
  let isLandscape: Bool

  #if os(tvOS)
    static let defaultSpacing: CGFloat = 40
  #else
    static let defaultSpacing: CGFloat = 16
  #endif

  init(
    width: CGFloat = 0, spacing: CGFloat = defaultSpacing,
    browseColumns: BrowseColumns = BrowseColumns()
  ) {
    self.width = width
    self.spacing = spacing
    self.browseColumns = browseColumns
    self.isLandscape = PlatformHelper.deviceOrientation.isLandscape
  }

  var availableWidth: CGFloat {
    max(0, width - spacing * 2)
  }

  var columnsCount: Int {
    isLandscape ? browseColumns.landscape : browseColumns.portrait
  }

  var cardWidth: CGFloat {
    guard columnsCount > 0 else { return availableWidth }
    let totalSpacing = CGFloat(columnsCount - 1) * spacing
    return max(0, (availableWidth - totalSpacing) / CGFloat(columnsCount))
  }

  var columns: [GridItem] {
    Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: max(columnsCount, 1))
  }
}
