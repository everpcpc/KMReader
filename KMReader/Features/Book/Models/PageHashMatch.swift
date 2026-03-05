//
// PageHashMatch.swift
//
//

import Foundation

struct PageHashMatch: Codable, Identifiable, Equatable {
  let bookId: String
  let url: String
  let pageNumber: Int
  let fileName: String
  let fileSize: Int64
  let mediaType: String

  var id: String { "\(bookId)-\(pageNumber)" }
}
