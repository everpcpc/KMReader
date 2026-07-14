//
// ArchiveExtractionService.swift
//
//

import Foundation
import ImageIO
import LibArchive

nonisolated enum ArchiveExtractionService {
  struct ExtractedFile: Sendable {
    let archivePath: String
    let destination: URL
  }

  static func extractFiles(
    from archiveFile: URL,
    destinationsByArchivePath: [String: URL],
    normalizePath: @Sendable (String) -> String?
  ) throws -> [ExtractedFile] {
    guard !destinationsByArchivePath.isEmpty else { return [] }

    let stagingDirectory = try makeStagingDirectory()
    defer {
      try? FileManager.default.removeItem(at: stagingDirectory)
    }

    try ArchiveReader().extract(
      archiveFile,
      to: stagingDirectory,
      permissionMode: .normalized
    )

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

  static func regularArchivePaths(
    in archiveFile: URL,
    normalizePath: @Sendable (String) -> String?
  ) throws -> [String: String] {
    let entries = try ArchiveReader().entries(at: archiveFile)
    var pathsByNormalizedPath: [String: String] = [:]

    for entry in entries where entry.fileType == .regular {
      guard let normalizedPath = normalizePath(entry.path) else { continue }
      pathsByNormalizedPath[normalizedPath] = entry.path
    }

    return pathsByNormalizedPath
  }

  static func fileData(
    from archiveFile: URL,
    entryPath: String
  ) throws -> Data {
    return try ArchiveReader().data(forEntryPath: entryPath, in: archiveFile)
  }

  static func imagePixelSize(at fileURL: URL) -> CGSize? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options) else {
      return nil
    }
    return imagePixelSize(from: source)
  }

  static func imagePixelSizes(
    from archiveFile: URL,
    entryPaths: Set<String>,
    normalizePath: @Sendable (String) -> String?
  ) throws -> [String: CGSize] {
    var pendingPathsByNormalizedPath: [String: [String]] = [:]
    for entryPath in entryPaths {
      guard let normalizedPath = normalizePath(entryPath) else { continue }
      pendingPathsByNormalizedPath[normalizedPath, default: []].append(entryPath)
    }
    guard !pendingPathsByNormalizedPath.isEmpty else { return [:] }

    var pixelSizes: [String: CGSize] = [:]
    var currentNormalizedPath: String?
    var currentEntryPaths: [String] = []
    var currentData = Data()
    var currentSource: CGImageSource?

    func captureCurrentPixelSize(isFinal: Bool) {
      guard let currentSource else { return }
      CGImageSourceUpdateData(currentSource, currentData as CFData, isFinal)
      guard let pixelSize = imagePixelSize(from: currentSource) else { return }

      for entryPath in currentEntryPaths {
        pixelSizes[entryPath] = pixelSize
      }
      if let currentNormalizedPath {
        pendingPathsByNormalizedPath.removeValue(forKey: currentNormalizedPath)
      }
    }

    try ArchiveReader().readDataBlocks(
      in: archiveFile,
      selecting: { entry in
        guard !pendingPathsByNormalizedPath.isEmpty else { return .stop }
        guard entry.fileType == .regular,
          let normalizedPath = normalizePath(entry.path),
          let requestedPaths = pendingPathsByNormalizedPath[normalizedPath]
        else {
          return .skip
        }

        currentNormalizedPath = normalizedPath
        currentEntryPaths = requestedPaths
        currentData.removeAll(keepingCapacity: true)
        currentSource = CGImageSourceCreateIncremental(nil)
        return .read
      },
      didFinishEntry: { _, consumedToEOF in
        if consumedToEOF {
          captureCurrentPixelSize(isFinal: true)
        }
        currentNormalizedPath = nil
        currentEntryPaths.removeAll(keepingCapacity: true)
        currentData.removeAll(keepingCapacity: true)
        currentSource = nil
      },
      { _, block in
        guard merge(block: block, into: &currentData) else {
          return .finishEntry
        }
        captureCurrentPixelSize(isFinal: false)
        guard let currentNormalizedPath else { return .finishEntry }
        return pendingPathsByNormalizedPath[currentNormalizedPath] == nil
          ? .finishEntry : .continueReading
      }
    )

    return pixelSizes
  }

  private static func makeStagingDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("KMReaderArchiveExtraction-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private static func imagePixelSize(from source: CGImageSource) -> CGSize? {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
        as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0,
      height > 0
    else {
      return nil
    }

    return CGSize(width: width, height: height)
  }

  private static func merge(block: ArchiveDataBlock, into data: inout Data) -> Bool {
    guard block.offset >= 0, block.offset <= Int64(Int.max) else { return false }
    let offset = Int(block.offset)
    guard block.data.count <= Int.max - offset else { return false }
    let endOffset = offset + block.data.count

    if data.count < offset {
      data.append(Data(repeating: 0, count: offset - data.count))
    }
    if data.count < endOffset {
      data.append(Data(repeating: 0, count: endOffset - data.count))
    }
    data.replaceSubrange(offset..<endOffset, with: block.data)
    return true
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
