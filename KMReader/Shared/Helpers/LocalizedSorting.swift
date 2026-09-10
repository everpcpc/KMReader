//
// LocalizedSorting.swift
//
// Locale-aware (ICU) sorting helper for user-facing metadata lists.
//
// `localizedStandardCompare` performs an ICU UCA collation using the app's
// current locale (Locale.current — the app follows the system language),
// with numeric, case-insensitive and width-insensitive options. This matches
// Finder-style ordering: "a" and "A" are adjacent, "Chapter 2" precedes
// "Chapter 10", and CJK text sorts by the locale's collation instead of raw
// Unicode code points.

import Foundation

extension Collection where Element == String {
  /// Sorts strings with locale-aware ICU collation, respecting the app language.
  func localizedSorted() -> [String] {
    sorted { lhs, rhs in
      lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
  }
}
