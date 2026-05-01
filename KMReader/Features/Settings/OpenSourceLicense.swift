//
// OpenSourceLicense.swift
//
//

import Foundation

struct OpenSourceLicense: Decodable, Identifiable, Hashable {
  let id: String
  let name: String
  let license: String
  let sourceURL: URL
  let notice: String
}
