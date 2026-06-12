//
// AuthenticationMethod.swift
//
//

import Foundation

nonisolated enum AuthenticationMethod: String, Codable, Sendable {
  case basicAuth
  case apiKey
}
