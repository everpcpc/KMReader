//
// CustomFontRecord.swift
//
//

import Foundation
import SQLiteData

@Table("custom_fonts")
nonisolated struct CustomFontRecord: Identifiable, Hashable, Sendable {
  let id: UUID
  var name: String
  var path: String?
  var fileName: String?
  var fileSize: Int64?
  @Column(as: Date.UnixTimeRepresentation.self)
  var createdAt: Date
}
