//
// ReadList.swift
//
//

import Foundation

struct ReadList: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let summary: String
  let ordered: Bool
  let bookIds: [String]
  let createdDate: Date
  let lastModifiedDate: Date
  let filtered: Bool
}
