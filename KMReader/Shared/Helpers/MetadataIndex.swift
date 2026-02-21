//
// MetadataIndex.swift
//
//

import Foundation

nonisolated enum MetadataIndex {
  private static let delimiter = "|"

  static func encode(value: String?) -> String {
    guard let normalized = normalize(value) else {
      return delimiter
    }
    return "\(delimiter)\(normalized)\(delimiter)"
  }

  static func encode(values: [String]) -> String {
    let normalized = values.compactMap(normalize)
    guard !normalized.isEmpty else {
      return delimiter
    }

    let stable = Array(Set(normalized)).sorted()
    return "\(delimiter)\(stable.joined(separator: delimiter))\(delimiter)"
  }

  static func contains(index: String, value: String) -> Bool {
    guard let normalized = normalize(value) else {
      return false
    }
    return index.contains("\(delimiter)\(normalized)\(delimiter)")
  }

  static func matches(index: String, values: [String]?, logic: FilterLogic) -> Bool {
    guard let values, !values.isEmpty else {
      return true
    }

    let normalized = values.compactMap(normalize)
    guard !normalized.isEmpty else {
      return true
    }

    switch logic {
    case .all:
      return normalized.allSatisfy { contains(index: index, value: $0) }
    case .any:
      return normalized.contains { contains(index: index, value: $0) }
    }
  }

  static func normalize(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let trimmed =
      value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: delimiter, with: " ")

    return trimmed.isEmpty ? nil : trimmed
  }
}
