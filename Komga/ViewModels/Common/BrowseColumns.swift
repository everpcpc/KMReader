//
//  BrowseOptions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct BrowseColumns: Equatable, RawRepresentable {
  typealias RawValue = String

  var portrait: Int
  var landscape: Int

  init() {
    self.portrait = getDefaultPortraitColumns()
    self.landscape = getDefaultLandscapeColumns()
  }

  // MARK: - RawRepresentable

  var rawValue: String {
    let dict: [String: Int] = [
      "portrait": portrait,
      "landscape": landscape,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  init?(rawValue: String) {
    guard !rawValue.isEmpty else {
      return nil
    }
    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Int]
    else {
      return nil
    }
    self.portrait = dict["portrait"] ?? getDefaultPortraitColumns()
    self.landscape = dict["landscape"] ?? getDefaultLandscapeColumns()
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
