//
// CustomFontDisplayItem.swift
//
//

import Foundation

nonisolated struct CustomFontDisplayItem: Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  let path: String?
  let fileName: String?
  let fileSize: Int64?

  init(name: String, path: String?, fileName: String?, fileSize: Int64?) {
    id = name
    self.name = name
    self.path = path
    self.fileName = fileName
    self.fileSize = fileSize
  }
}
