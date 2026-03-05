//
// PageHashCreation.swift
//
//

import Foundation

struct PageHashCreation: Codable {
  let hash: String
  let size: Int64?
  let action: PageHashAction
}
