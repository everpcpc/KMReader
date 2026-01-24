//
//  CustomFont.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

typealias CustomFont = CustomFontV1

@Model
final class CustomFontV1 {
  @Attribute(.unique) var name: String
  var path: String?  // File path for imported fonts, nil for system/manual fonts
  var fileName: String?  // Original file name for imported fonts
  var fileSize: Int64?  // File size in bytes for imported fonts
  var createdAt: Date

  init(name: String, path: String? = nil, fileName: String? = nil, fileSize: Int64? = nil, createdAt: Date = Date()) {
    self.name = name
    self.path = path
    self.fileName = fileName
    self.fileSize = fileSize
    self.createdAt = createdAt
  }
}
