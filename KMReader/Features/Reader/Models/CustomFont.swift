//
// CustomFont.swift
//

import Foundation

nonisolated struct CustomFont: Codable, Equatable, Sendable {
  var name: String
  var path: String?
  var fileName: String?
  var fileSize: Int64?
  var createdAt: Date

  init(
    name: String,
    path: String? = nil,
    fileName: String? = nil,
    fileSize: Int64? = nil,
    createdAt: Date = Date()
  ) {
    self.name = name
    self.path = path
    self.fileName = fileName
    self.fileSize = fileSize
    self.createdAt = createdAt
  }
}
