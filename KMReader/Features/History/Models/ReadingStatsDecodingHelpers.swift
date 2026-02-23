//
// ReadingStatsDecodingHelpers.swift
//
//

import Foundation

extension KeyedDecodingContainer {
  nonisolated func decodeFirstString(forKeys keys: [Key]) throws -> String? {
    for key in keys {
      if let value = try decodeIfPresent(String.self, forKey: key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          return trimmed
        }
      }
    }
    return nil
  }

  nonisolated func decodeFirstDouble(forKeys keys: [Key]) throws -> Double? {
    for key in keys {
      if let value = try decodeIfPresent(Double.self, forKey: key) {
        return value
      }
      if let value = try decodeIfPresent(Int.self, forKey: key) {
        return Double(value)
      }
      if let value = try decodeIfPresent(Int64.self, forKey: key) {
        return Double(value)
      }
      if let value = try decodeIfPresent(String.self, forKey: key),
        let parsed = Double(value)
      {
        return parsed
      }
    }
    return nil
  }

  nonisolated func decodeFirstArray<T: Decodable>(_ type: [T].Type, forKeys keys: [Key]) throws -> [T]? {
    for key in keys {
      if let value = try decodeIfPresent(type, forKey: key) {
        return value
      }
    }
    return nil
  }
}
