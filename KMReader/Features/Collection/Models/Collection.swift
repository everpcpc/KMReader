//
//  Collection.swift
//  Komga
//
//

import Foundation

struct SeriesCollection: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let ordered: Bool
  let seriesIds: [String]
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
}
