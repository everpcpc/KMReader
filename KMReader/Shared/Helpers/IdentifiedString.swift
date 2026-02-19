//
// IdentifiedString.swift
//
//

struct IdentifiedString: Identifiable, Equatable {
  let id: String

  init(_ value: String) {
    self.id = value
  }
}
