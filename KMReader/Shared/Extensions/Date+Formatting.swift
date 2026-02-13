//
//  Date+Formatting.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

extension Date {
  private static let mediumDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  private static let mediumDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  var formattedMediumDate: String {
    Self.mediumDateFormatter.string(from: self)
  }

  var formattedMediumDateTime: String {
    Self.mediumDateTimeFormatter.string(from: self)
  }
}
