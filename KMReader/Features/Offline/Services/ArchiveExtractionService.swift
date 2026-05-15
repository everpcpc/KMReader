//
// ArchiveExtractionService.swift
//
//

import Foundation
import LibArchive

nonisolated enum ArchiveExtractionService {
  struct ExtractedFile: Sendable {
    let archivePath: String
    let destination: URL
  }

  static func extractFiles(
    from archiveFile: URL,
    destinationsByArchivePath: [String: URL],
    normalizePath: (String) -> String?
  ) throws -> [ExtractedFile] {
    guard !destinationsByArchivePath.isEmpty else { return [] }

    let stagingDirectory = try makeStagingDirectory()
    defer {
      try? FileManager.default.removeItem(at: stagingDirectory)
    }

    try ArchiveReader().extract(archiveFile, to: stagingDirectory, permissionMode: .normalized)

    let extractedFiles = try regularFiles(in: stagingDirectory)
    var remainingDestinations = destinationsByArchivePath
    var extracted: [ExtractedFile] = []

    for fileURL in extractedFiles {
      let relativePath = relativePath(for: fileURL, under: stagingDirectory)
      guard
        let archivePath = normalizePath(relativePath),
        let destination = remainingDestinations.removeValue(forKey: archivePath)
      else { continue }

      try moveExtractedFile(from: fileURL, to: destination)
      extracted.append(ExtractedFile(archivePath: archivePath, destination: destination))

      if remainingDestinations.isEmpty {
        break
      }
    }

    return extracted
  }

  private static func makeStagingDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("KMReaderArchiveExtraction-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private static func regularFiles(in directory: URL) throws -> [URL] {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
      )
    else { return [] }

    var files: [URL] = []
    for case let fileURL as URL in enumerator {
      let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
      if values.isRegularFile == true {
        files.append(fileURL)
      }
    }
    return files
  }

  private static func relativePath(for fileURL: URL, under directory: URL) -> String {
    let rootPath = directory.standardizedFileURL.path
    let filePath = fileURL.standardizedFileURL.path
    guard filePath.hasPrefix(rootPath + "/") else {
      return fileURL.lastPathComponent
    }
    return String(filePath.dropFirst(rootPath.count + 1))
  }

  private static func moveExtractedFile(from source: URL, to destination: URL) throws {
    let directory = destination.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }

    try FileManager.default.moveItem(at: source, to: destination)
  }
}
