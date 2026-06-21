//
// OfflinePolicy+ButtonStyle.swift
//
//

import SwiftUI

extension OfflinePolicy {
  var buttonTint: Color {
    switch self {
    case .manual:
      return .gray
    case .unreadOnly:
      return .orange
    case .all:
      return .green
    }
  }
}
