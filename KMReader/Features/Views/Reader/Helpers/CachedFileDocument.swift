//
//  CachedFileDocument.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS) || os(macOS)
  /// Generic file-document wrapper used by fileExporter to expose cached files.
  struct CachedFileDocument: FileDocument {
    let url: URL
    let fileType: UTType?

    static var readableContentTypes: [UTType] {
      [.item]
    }

    static var writableContentTypes: [UTType] {
      [.item]
    }

    init(url: URL) {
      self.url = url
      // Detect file type from extension
      self.fileType = UTType(filenameExtension: url.pathExtension)
    }

    init(configuration: ReadConfiguration) throws {
      guard let data = configuration.file.regularFileContents,
        let url = URL(dataRepresentation: data, relativeTo: nil)
      else {
        throw CocoaError(.fileReadCorruptFile)
      }
      self.url = url
      self.fileType = UTType(filenameExtension: url.pathExtension)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
      let data = try Data(contentsOf: url)
      return FileWrapper(regularFileWithContents: data)
    }
  }
#endif
