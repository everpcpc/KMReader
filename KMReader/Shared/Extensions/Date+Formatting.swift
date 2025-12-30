//
//  Date+Formatting.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

extension Date {
  /// Formats the date using medium date style without time
  var formattedMediumDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: self)
  }

  /// Formats the date using medium date style with time
  var formattedMediumDateTime: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: self)
  }
}
