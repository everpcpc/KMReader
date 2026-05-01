//
// OpenSourceLicenseStore.swift
//
//

import Foundation

struct OpenSourceLicenseStore {
  static func load() -> [OpenSourceLicense] {
    guard let url = resourceURL else {
      AppLogger(.app).error("OpenSourceLicenses.json was not found in the app bundle")
      return []
    }

    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([OpenSourceLicense].self, from: data)
    } catch {
      AppLogger(.app).error("Failed to decode open source licenses: \(error.localizedDescription)")
      return []
    }
  }

  private static var resourceURL: URL? {
    Bundle.main.url(forResource: "OpenSourceLicenses", withExtension: "json", subdirectory: "Resources")
      ?? Bundle.main.url(forResource: "OpenSourceLicenses", withExtension: "json")
  }
}
