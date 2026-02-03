//
//  TriStateFilter.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

nonisolated enum TriStateSelection: String, Codable {
  case off
  case include
  case exclude
}

nonisolated enum FilterLogic: String, Codable {
  case all = "ALL"
  case any = "ANY"
}

nonisolated enum BoolTriStateFlag: String {
  case yes = "true"

  var boolValue: Bool {
    self == .yes
  }
}

nonisolated struct TriStateFilter<Value: RawRepresentable & Equatable>: Equatable
where Value.RawValue == String {
  var state: TriStateSelection
  var value: Value?

  init(state: TriStateSelection = .off, value: Value? = nil) {
    self.state = state
    self.value = value
  }

  static func include(_ value: Value) -> Self {
    Self(state: .include, value: value)
  }

  static func exclude(_ value: Value) -> Self {
    Self(state: .exclude, value: value)
  }

  var isActive: Bool {
    state != .off && value != nil
  }

  var includedValue: Value? {
    state == .include ? value : nil
  }

  var excludedValue: Value? {
    state == .exclude ? value : nil
  }

  mutating func cycle(to newValue: Value) {
    if value == newValue {
      switch state {
      case .include:
        state = .exclude
      case .exclude:
        state = .off
      case .off:
        state = .include
      }
    } else {
      state = .include
      value = newValue
    }

    if state == .off {
      value = nil
    }
  }

  func state(for option: Value) -> TriStateSelection {
    guard let current = value, current == option else {
      return .off
    }
    return state
  }

  func displayLabel(using provider: (Value) -> String) -> String? {
    guard let value else { return nil }
    let base = provider(value)
    return state == .exclude ? "≠ \(base)" : base
  }

  var storageValue: String {
    guard let value, state != .off else {
      return TriStateSelection.off.rawValue
    }
    return "\(state.rawValue):\(value.rawValue)"
  }

  static func decode(_ raw: String?, offValues: [Value] = []) -> Self {
    guard let raw, !raw.isEmpty else { return Self() }
    if raw == TriStateSelection.off.rawValue {
      return Self()
    }

    let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
    if parts.count == 2,
      let state = TriStateSelection(rawValue: parts[0]),
      let value = Value(rawValue: parts[1])
    {
      return .init(state: state, value: value)
    }

    if let legacyValue = Value(rawValue: raw) {
      if offValues.contains(legacyValue) {
        return Self()
      }
      return .include(legacyValue)
    }

    return Self()
  }
}

extension TriStateFilter where Value == ReadStatus {
  var includedReadStatus: ReadStatus? {
    includedValue
  }

  var excludedReadStatus: ReadStatus? {
    excludedValue
  }
}

extension TriStateFilter where Value == SeriesStatus {
  var includedSeriesStatus: String? {
    includedValue?.apiValue
  }

  var excludedSeriesStatus: String? {
    excludedValue?.apiValue
  }
}

extension TriStateFilter where Value == BoolTriStateFlag {
  nonisolated var includedBool: Bool? {
    includedValue?.boolValue
  }

  nonisolated var excludedBool: Bool? {
    excludedValue?.boolValue
  }

  /// Prefer an explicit include value; otherwise flip the excluded value if present.
  nonisolated var effectiveBool: Bool? {
    if let include = includedBool {
      return include
    }
    if let exclude = excludedBool {
      return !exclude
    }
    return nil
  }
}
