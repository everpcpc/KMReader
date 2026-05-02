//
// LocalDataResetService.swift
//
//

import Foundation

enum LocalDataResetService {
  static func resetAllLocalData() throws {
    let fileManager = FileManager.default

    for directory in resetDirectories(fileManager: fileManager) {
      try removeDirectoryContents(at: directory, fileManager: fileManager)
    }

    resetStandardDefaults()
    resetSharedDefaults()
  }

  private static func resetDirectories(fileManager: FileManager) -> [URL] {
    var directories: [URL] = []

    if let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first {
      directories.append(applicationSupport)
    }

    if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
      directories.append(caches)
    }

    if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
      directories.append(documents.appendingPathComponent("OfflineBooks", isDirectory: true))
    }

    if let sharedContainer = WidgetDataStore.sharedContainerURL {
      directories.append(sharedContainer.appendingPathComponent("WidgetThumbnails", isDirectory: true))
    }

    return directories
  }

  private static func removeDirectoryContents(at directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
      return
    }

    if !isDirectory.boolValue {
      try fileManager.removeItem(at: directory)
      return
    }

    let contents = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: []
    )

    for item in contents {
      try fileManager.removeItem(at: item)
    }
  }

  private static func resetStandardDefaults() {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      return
    }

    UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
    UserDefaults.standard.synchronize()
  }

  private static func resetSharedDefaults() {
    guard let defaults = WidgetDataStore.sharedDefaults else {
      return
    }

    for key in defaults.dictionaryRepresentation().keys {
      defaults.removeObject(forKey: key)
    }
    defaults.synchronize()
  }
}
