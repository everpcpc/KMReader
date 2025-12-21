//
//  CustomFont.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@Model
final class CustomFont {
  @Attribute(.unique) var name: String
  var createdAt: Date

  init(name: String, createdAt: Date = Date()) {
    self.name = name
    self.createdAt = createdAt
  }
}
