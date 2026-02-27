//
// ReadingStatsViewModel.swift
//
//

import Foundation

@MainActor
@Observable
final class ReadingStatsViewModel {
  var payload: ReadingStatsPayload?
  var lastUpdatedAt: Date?
  var selectedTimeRange: ReadingStatsTimeRange = .last30Days
  var isLoading = false
  var isRefreshing = false
  var isUsingCachedData = false
  var errorMessage: String?

  // Cached stats are immediately displayed; if last refresh is older than this interval, refresh in background.
  private let autoRefreshInterval: TimeInterval = 24 * 60 * 60
  private let service = ReadingStatsService.shared
  private let cacheStore = ReadingStatsCacheStore.shared

  func load(instanceId: String, libraryId: String, forceRefresh: Bool = false) async {
    guard !instanceId.isEmpty else {
      payload = nil
      lastUpdatedAt = nil
      errorMessage = nil
      isUsingCachedData = false
      return
    }

    let cachedSnapshot = cacheStore.snapshot(instanceId: instanceId, libraryId: libraryId)

    if let cachedSnapshot {
      apply(snapshot: cachedSnapshot, usingCache: true)

      let cacheAge = Date().timeIntervalSince(cachedSnapshot.cachedAt)
      if forceRefresh == false && cacheAge <= autoRefreshInterval {
        return
      }
    }

    errorMessage = nil
    if payload == nil {
      isLoading = true
    } else {
      isRefreshing = true
    }

    do {
      let fetched = try await service.fetchReadingStats(libraryId: normalizedLibraryId(libraryId))
      let snapshot = ReadingStatsSnapshot(libraryId: normalizedLibraryId(libraryId), cachedAt: Date(), payload: fetched)
      cacheStore.upsert(snapshot: snapshot, instanceId: instanceId, libraryId: libraryId)
      apply(snapshot: snapshot, usingCache: false)
    } catch {
      if let cachedSnapshot {
        apply(snapshot: cachedSnapshot, usingCache: true)
        errorMessage = String(localized: "Failed to refresh reading stats. Showing cached data.")
      } else {
        payload = nil
        lastUpdatedAt = nil
        errorMessage = error.localizedDescription
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
    isRefreshing = false
  }

  func filteredTimeSeries(referenceDate: Date = Date()) -> [ReadingStatsTimePoint] {
    guard let readingTimeSeries = payload?.readingTimeSeries, !readingTimeSeries.isEmpty else {
      return []
    }

    let dailyPoints = readingTimeSeries.compactMap { point -> (date: Date, hours: Double)? in
      guard let parsedDate = Self.parseDate(point.dateString ?? point.name) else {
        return nil
      }
      return (Self.utcCalendar.startOfDay(for: parsedDate), point.value)
    }

    guard !dailyPoints.isEmpty else {
      return []
    }

    let now = Self.utcCalendar.startOfDay(for: referenceDate)
    let earliestDate = dailyPoints.map(\.date).min() ?? now
    let window = makeTimeSeriesWindow(referenceDate: now, earliestDate: earliestDate)

    var hoursByKey: [String: Double] = [:]
    for point in dailyPoints {
      guard point.date >= window.startDate && point.date <= window.endDate else { continue }
      let key = Self.groupKey(for: point.date, grouping: window.grouping)
      hoursByKey[key, default: 0] += point.hours
    }

    if window.grouping == .day {
      let todayKey = Self.groupKey(for: window.endDate, grouping: .day)
      if hoursByKey[todayKey] == nil {
        hoursByKey[todayKey] = 0
      }
    }

    if window.startDate > window.endDate {
      let todayKey = Self.groupKey(for: window.endDate, grouping: .day)
      let todayLabel = formatAxisLabel(key: todayKey, grouping: .day)
      return [ReadingStatsTimePoint(name: todayLabel, value: 0, dateString: todayKey)]
    }

    var series: [ReadingStatsTimePoint] = []
    var cursor = window.startDate

    while cursor <= window.endDate {
      let key = Self.groupKey(for: cursor, grouping: window.grouping)
      let value = hoursByKey[key, default: 0]

      series.append(
        ReadingStatsTimePoint(
          name: formatAxisLabel(key: key, grouping: window.grouping),
          value: (value * 100).rounded() / 100,
          dateString: key
        )
      )

      guard let nextCursor = Self.nextDate(from: cursor, grouping: window.grouping) else {
        break
      }
      cursor = nextCursor
    }

    if window.grouping == .day {
      let todayKey = Self.groupKey(for: window.endDate, grouping: .day)
      let hasToday = series.contains { $0.dateString == todayKey }
      if !hasToday {
        series.append(
          ReadingStatsTimePoint(
            name: formatAxisLabel(key: todayKey, grouping: .day),
            value: 0,
            dateString: todayKey
          )
        )
      }
    }

    return series
  }

  private func makeTimeSeriesWindow(referenceDate: Date, earliestDate: Date) -> ReadingTimeWindow {
    let now = Self.utcCalendar.startOfDay(for: referenceDate)
    let year = Self.utcCalendar.component(.year, from: now)
    let month = Self.utcCalendar.component(.month, from: now)
    let day = Self.utcCalendar.component(.day, from: now)
    let weekday = Self.utcCalendar.component(.weekday, from: now)

    let startDate: Date
    let grouping: ReadingTimeGrouping

    switch selectedTimeRange {
    case .thisWeek:
      let offset = weekday - 1
      startDate = Self.utcCalendar.date(byAdding: .day, value: -offset, to: now) ?? now
      grouping = .day
    case .last7Days:
      startDate = Self.utcCalendar.date(byAdding: .day, value: -6, to: now) ?? now
      grouping = .day
    case .last30Days:
      startDate = Self.utcCalendar.date(byAdding: .day, value: -29, to: now) ?? now
      grouping = .day
    case .last90Days:
      startDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month - 2, day: 1)) ?? now
      grouping = .month
    case .last6Months:
      startDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month - 5, day: 1)) ?? now
      grouping = .month
    case .lastYear:
      startDate = Self.utcCalendar.date(from: DateComponents(year: year - 1, month: month + 1, day: 1)) ?? now
      grouping = .month
    case .allTime:
      startDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? earliestDate
      grouping = .year
    }

    if selectedTimeRange == .allTime {
      return ReadingTimeWindow(startDate: earliestDate, endDate: now, grouping: grouping)
    }

    return ReadingTimeWindow(
      startDate: Self.utcCalendar.startOfDay(for: startDate),
      endDate: now,
      grouping: grouping
    )
  }

  private func formatAxisLabel(key: String, grouping: ReadingTimeGrouping) -> String {
    switch grouping {
    case .day:
      guard let date = Self.dayKeyFormatter.date(from: key) else { return key }
      return Self.dayAxisLabelFormatter.string(from: date)
    case .month:
      guard let date = Self.monthKeyFormatter.date(from: key) else { return key }
      return Self.monthAxisLabelFormatter.string(from: date)
    case .year:
      return key
    }
  }

  private static func groupKey(for date: Date, grouping: ReadingTimeGrouping) -> String {
    switch grouping {
    case .day:
      return dayKeyFormatter.string(from: date)
    case .month:
      return monthKeyFormatter.string(from: date)
    case .year:
      return yearKeyFormatter.string(from: date)
    }
  }

  private static func nextDate(from date: Date, grouping: ReadingTimeGrouping) -> Date? {
    switch grouping {
    case .day:
      return utcCalendar.date(byAdding: .day, value: 1, to: date)
    case .month:
      return utcCalendar.date(byAdding: .month, value: 1, to: date)
    case .year:
      return utcCalendar.date(byAdding: .year, value: 1, to: date)
    }
  }

  private enum ReadingTimeGrouping {
    case day
    case month
    case year
  }

  private struct ReadingTimeWindow {
    let startDate: Date
    let endDate: Date
    let grouping: ReadingTimeGrouping
  }

  static func parseDate(_ rawValue: String?) -> Date? {
    guard let rawValue else { return nil }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let date = iso8601WithFractional.date(from: trimmed) {
      return date
    }
    if let date = iso8601.date(from: trimmed) {
      return date
    }

    for formatter in additionalDateFormatters {
      if let date = formatter.date(from: trimmed) {
        return date
      }
    }

    return nil
  }

  private func apply(snapshot: ReadingStatsSnapshot, usingCache: Bool) {
    payload = snapshot.payload
    lastUpdatedAt = snapshot.cachedAt
    isUsingCachedData = usingCache
  }

  private func normalizedLibraryId(_ libraryId: String) -> String {
    libraryId.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let iso8601WithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let additionalDateFormatters: [DateFormatter] = {
    let formats = [
      "yyyy-MM-dd",
      "yyyy-MM",
      "yyyy",
      "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss.SSS",
    ]

    return formats.map { format in
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = .current
      formatter.dateFormat = format
      return formatter
    }
  }()

  private static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }()

  private static let dayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let monthKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM"
    return formatter
  }()

  private static let yearKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy"
    return formatter
  }()

  private static let dayAxisLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter
  }()

  private static let monthAxisLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("yMMM")
    return formatter
  }()
}
