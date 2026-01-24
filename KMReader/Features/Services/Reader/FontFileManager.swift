//
//  FontFileManager.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Manages font file storage in Application Support directory
enum FontFileManager {
  /// Returns the base directory for custom fonts
  static func fontsDirectory() -> URL? {
    guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    let fontsDir = appSupportURL.appendingPathComponent("CustomFonts", isDirectory: true)
    ensureDirectoryExists(at: fontsDir)
    return fontsDir
  }

  /// Resolves a relative font path to an absolute path
  /// - Parameter relativePath: Relative path like "CustomFonts/font.ttf"
  /// - Returns: Absolute file path, or nil if resolution fails
  static func resolvePath(_ relativePath: String) -> String? {
    guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    return appSupportURL.appendingPathComponent(relativePath).path
  }

  /// Creates a relative path for a font file
  /// - Parameter fileName: The font file name
  /// - Returns: Relative path like "CustomFonts/font.ttf"
  static func relativePath(for fileName: String) -> String {
    return "CustomFonts/\(fileName)"
  }

  /// Copies a font file to the fonts directory
  /// - Parameters:
  ///   - sourceURL: Source file URL
  ///   - fileName: Destination file name
  /// - Returns: Relative path of the copied file, or nil if copy fails
  static func copyFont(from sourceURL: URL, fileName: String) throws -> String {
    guard let fontsDir = fontsDirectory() else {
      throw FontFileError.directoryAccessFailed
    }

    let destinationURL = fontsDir.appendingPathComponent(fileName)

    // Remove existing file if it exists
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return relativePath(for: fileName)
  }

  /// Deletes a font file
  /// - Parameter relativePath: Relative path like "CustomFonts/font.ttf"
  static func deleteFont(at relativePath: String) {
    guard let absolutePath = resolvePath(relativePath) else { return }
    let fileURL = URL(fileURLWithPath: absolutePath)
    try? FileManager.default.removeItem(at: fileURL)
  }

  /// Checks if a font file exists
  /// - Parameter relativePath: Relative path like "CustomFonts/font.ttf"
  /// - Returns: true if file exists, false otherwise
  static func fileExists(at relativePath: String) -> Bool {
    guard let absolutePath = resolvePath(relativePath) else { return false }
    return FileManager.default.fileExists(atPath: absolutePath)
  }

  // MARK: - Helpers

  private static func ensureDirectoryExists(at url: URL) {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      return
    }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}

enum FontFileError: Error {
  case directoryAccessFailed
}
