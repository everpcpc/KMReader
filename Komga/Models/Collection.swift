//
//  Collection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Collection: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let ordered: Bool
  let seriesIds: [String]
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
}
