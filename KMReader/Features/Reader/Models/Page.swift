//
//  Page.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Page<T: Codable>: Codable {
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

struct Pageable: Codable {
  let sort: Sort
  let offset: Int
  let pageNumber: Int
  let pageSize: Int
  let paged: Bool
  let unpaged: Bool
}

struct Sort: Codable {
  let sorted: Bool
  let unsorted: Bool
  let empty: Bool
}
