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
  let height: CGFloat
  let spacing: CGFloat
  let browseColumns: BrowseColumns

  var availableWidth: CGFloat {
    width - spacing * 2
  }

  var isLandscape: Bool {
    let orientation = PlatformHelper.deviceOrientation
    return orientation.isLandscape || (orientation == .unknown && width > height)
  }

  var columnsCount: Int {
    isLandscape ? browseColumns.landscape : browseColumns.portrait
  }

  var cardWidth: CGFloat {
    guard columnsCount > 0 else { return availableWidth }
    let totalSpacing = CGFloat(columnsCount - 1) * spacing
    return (availableWidth - totalSpacing) / CGFloat(columnsCount)
  }

  var columns: [GridItem] {
    Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: max(columnsCount, 1))
  }
}
