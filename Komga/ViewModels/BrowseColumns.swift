//
//  BrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct BrowseColumns: Equatable, RawRepresentable, Codable {
  typealias RawValue = String

  var portrait: Int
  var landscape: Int

  init() {
    self.portrait = getDefaultPortraitColumns()
    self.landscape = getDefaultLandscapeColumns()
  }

  // MARK: - RawRepresentable

  var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
      let jsonString = String(data: data, encoding: .utf8)
    else {
      // Fallback to default JSON if encoding fails
      return
        "{\"portrait\":\(getDefaultPortraitColumns()),\"landscape\":\(getDefaultLandscapeColumns())}"
    }
    return jsonString
  }

  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(BrowseColumns.self, from: data)
    else {
      return nil
    }
    self.portrait = decoded.portrait
    self.landscape = decoded.landscape
  }
}

private func getDefaultPortraitColumns() -> Int {
  if UIDevice.current.userInterfaceIdiom == .pad {
    return 4
  } else {
    return 2
  }
}

private func getDefaultLandscapeColumns() -> Int {
  if UIDevice.current.userInterfaceIdiom == .pad {
    return 6
  } else {
    return 4
  }
}
