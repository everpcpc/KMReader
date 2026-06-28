//
// FontFileManager.swift
//
//

import Foundation

/// Manages font file storage in the app support directory.
enum FontFileManager {
  /// Returns the base directory for custom fonts
  static func fontsDirectory() -> URL? {
    guard let supportDirectory = try? AppStorageDirectory.supportDirectory() else { return nil }
    let fontsDir = supportDirectory.appendingPathComponent("CustomFonts", isDirectory: true)
    ensureDirectoryExists(at: fontsDir)
    return fontsDir
  }

  /// Resolves a relative font path to an absolute path
  /// - Parameter relativePath: Relative path like "CustomFonts/font.ttf"
  /// - Returns: Absolute file path, or nil if resolution fails
  static func resolvePath(_ relativePath: String) -> String? {
    guard let supportDirectory = try? AppStorageDirectory.supportDirectory() else { return nil }
    return supportDirectory.appendingPathComponent(relativePath).path
  }

  /// Resolves a font file by its stored file name.
  /// - Parameter fileName: Stored custom font file name.
  /// - Returns: Absolute file URL, or nil if the file is not available.
  static func resolveFontFile(named fileName: String) -> URL? {
    guard !fileName.contains("/"), !fileName.contains("\\") else { return nil }
    guard let fontsDir = fontsDirectory() else { return nil }
    let fileURL = fontsDir.appendingPathComponent(fileName).standardizedFileURL
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return fileURL
  }

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
    try? AppStorageDirectory.ensureDirectoryExists(at: url)
  }
}

enum FontFileError: Error {
  case directoryAccessFailed
}
