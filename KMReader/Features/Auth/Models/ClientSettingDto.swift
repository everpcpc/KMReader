//
// ClientSettingDto.swift
//
//

import Foundation

/// One entry of Komga's client settings lists (global or per user).
nonisolated struct ClientSettingDto: Decodable, Sendable {
  let value: String
}
