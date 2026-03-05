//
// PageHashUnknown.swift
//
//

import Foundation

struct PageHashUnknown: Codable, Identifiable, Equatable {
  let hash: String
  let matchCount: Int
  let size: Int64?

  var id: String { hash }
}
