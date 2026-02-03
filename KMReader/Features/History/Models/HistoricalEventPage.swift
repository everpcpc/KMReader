//
//  HistoricalEventPage.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

struct HistoricalEventPage: Decodable {
  let content: [HistoricalEvent]?
  let empty: Bool?
  let first: Bool?
  let last: Bool?
  let number: Int?
  let numberOfElements: Int?
  let size: Int?
  let totalElements: Int64?
  let totalPages: Int?
}
