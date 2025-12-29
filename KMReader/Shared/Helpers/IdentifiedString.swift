//
//  IdentifiedString.swift
//  KMReader
//
//  Created by Komga iOS Client
//

struct IdentifiedString: Identifiable, Equatable {
  let id: String

  init(_ value: String) {
    self.id = value
  }
}
