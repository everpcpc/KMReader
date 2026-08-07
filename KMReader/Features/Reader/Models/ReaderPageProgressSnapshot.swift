//
// ReaderPageProgressSnapshot.swift
//

import Foundation

struct ReaderPageProgressSnapshot: Equatable, Sendable {
  let bookId: String
  let page: Int
  let completed: Bool
}
