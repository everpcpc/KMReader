//
// ReadingStatsTimeRange.swift
//
//

import Foundation

nonisolated enum ReadingStatsTimeRange: String, CaseIterable, Sendable {
  case thisWeek
  case last7Days
  case last30Days
  case last90Days
  case last6Months
  case lastYear
  case allTime

  var title: String {
    switch self {
    case .thisWeek:
      return String(localized: "This Week")
    case .last7Days:
      return String(localized: "Last 7 Days")
    case .last30Days:
      return String(localized: "Last 30 Days")
    case .last90Days:
      return String(localized: "Last 90 Days")
    case .last6Months:
      return String(localized: "Last 6 Months")
    case .lastYear:
      return String(localized: "Last Year")
    case .allTime:
      return String(localized: "All Time")
    }
  }

  func startDate(reference: Date = Date(), calendar: Calendar = .current) -> Date? {
    switch self {
    case .thisWeek:
      let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference)
      return calendar.date(from: components)
    case .last7Days:
      return calendar.date(byAdding: .day, value: -6, to: reference)
    case .last30Days:
      return calendar.date(byAdding: .day, value: -29, to: reference)
    case .last90Days:
      return calendar.date(byAdding: .day, value: -89, to: reference)
    case .last6Months:
      return calendar.date(byAdding: .month, value: -6, to: reference)
    case .lastYear:
      return calendar.date(byAdding: .year, value: -1, to: reference)
    case .allTime:
      return nil
    }
  }
}
