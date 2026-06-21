//
// ReadListBookMembership.swift
//
//

import Foundation
import GRDB

nonisolated struct ReadListBookMembership: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
  static let databaseTableName = "read_list_books"

  let instanceId: String
  let readListId: String
  let bookId: String
  let position: Int

  enum CodingKeys: String, CodingKey {
    case instanceId = "instance_id"
    case readListId = "read_list_id"
    case bookId = "book_id"
    case position
  }
}
