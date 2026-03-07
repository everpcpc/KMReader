//
// Page.swift
//
//

import Foundation

nonisolated struct Page<T: Codable & Sendable>: Codable, Sendable {
  let content: [T]
  let pageable: Pageable
  let totalElements: Int
  let totalPages: Int
  let last: Bool
  let size: Int
  let number: Int
  let numberOfElements: Int
  let first: Bool
  let empty: Bool
}

nonisolated struct Pageable: Codable, Sendable {
  let sort: Sort
  let offset: Int
  let pageNumber: Int
  let pageSize: Int
  let paged: Bool
  let unpaged: Bool
}

nonisolated struct Sort: Codable, Sendable {
  let sorted: Bool
  let unsorted: Bool
  let empty: Bool
}
