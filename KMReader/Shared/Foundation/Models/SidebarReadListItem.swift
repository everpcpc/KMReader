//
// SidebarReadListItem.swift
//
//

import Foundation

nonisolated struct SidebarReadListItem: Hashable, Identifiable, Sendable {
  let id: String
  let readListId: String
  let name: String
  let bookCount: Int

  init(readListId: String, name: String, bookCount: Int) {
    id = readListId
    self.readListId = readListId
    self.name = name
    self.bookCount = bookCount
  }
}
