//
//  Series+Extensions.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension Series {
  private var normalizedStatus: String {
    (metadata.status ?? "Unknown").uppercased()
  }

  var statusDisplayName: String {
    switch normalizedStatus {
    case "ONGOING": return "Ongoing"
    case "ENDED": return "Ended"
    case "ABANDONED": return "Abandoned"
    case "HIATUS": return "Hiatus"
    default: return (metadata.status ?? "Unknown").capitalized
    }
  }

  var statusColor: Color {
    switch normalizedStatus {
    case "ONGOING": return .blue
    case "ENDED": return .green
    case "ABANDONED": return .red
    case "HIATUS": return .orange
    default: return .secondary
    }
  }

  var statusIcon: String {
    switch normalizedStatus {
    case "ONGOING": return "bolt.circle"
    case "ENDED": return "checkmark.circle"
    case "ABANDONED": return "exclamationmark.circle"
    case "HIATUS": return "pause.circle"
    default: return "questionmark.circle"
    }
  }

  var lastUpdatedDisplay: String {
    lastModified.formatted(date: .abbreviated, time: .omitted)
  }

  var readStatusColor: Color {
    if booksCount == 0 {
      return .secondary
    } else if booksReadCount == booksCount {
      return .green
    } else if booksReadCount > 0 {
      return .blue
    } else {
      return .secondary
    }
  }
}
