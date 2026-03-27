//
// KomgaBook+Display.swift
//
//

import Foundation

extension KomgaBook {
  var completedLastReadText: String? {
    guard isCompleted, let progressReadDate else { return nil }
    return progressReadDate.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
  }
}
