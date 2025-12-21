//
//  ReadProgress.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct ReadProgress: Codable, Equatable, Hashable, Sendable {
  let page: Int
  let completed: Bool
  let readDate: Date
  let created: Date
  let lastModified: Date
}
