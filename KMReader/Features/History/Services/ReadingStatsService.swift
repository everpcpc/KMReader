//
// ReadingStatsService.swift
//
//

import Foundation

class ReadingStatsService {
  static let shared = ReadingStatsService()

  private let bookService = BookService.shared
  private let seriesService = SeriesService.shared

  private init() {}

  func fetchReadingStats(libraryId: String?) async throws -> ReadingStatsPayload {
    let normalizedLibraryId = normalizeLibraryId(libraryId)

    async let readBooksTask = fetchReadBooks()
    async let readSeriesTask = fetchReadSeries()
    async let totalBooksTask = fetchTotalBooks(libraryId: normalizedLibraryId)

    let readBooks = try await readBooksTask
    let readSeries = try await readSeriesTask
    let totalBooks = try await totalBooksTask

    let filteredBooks: [Book]
    if let normalizedLibraryId {
      filteredBooks = readBooks.filter { $0.libraryId == normalizedLibraryId }
    } else {
      filteredBooks = readBooks
    }

    return buildPayload(
      filteredBooks: filteredBooks,
      readSeries: readSeries,
      totalBooks: totalBooks
    )
  }

  // MARK: - Data loading (aligned with ReadingStatsView.vue)

  private func fetchReadBooks() async throws -> [Book] {
    let condition: [String: Any] = [
      "readStatus": [
        "operator": "isNot",
        "value": ReadStatus.unread.rawValue,
      ]
    ]

    let page = try await bookService.getBooksList(
      search: BookSearch(condition: condition),
      unpaged: true
    )

    return page.content
  }

  private func fetchReadSeries() async throws -> [Series] {
    let condition: [String: Any] = [
      "readStatus": [
        "operator": "isNot",
        "value": ReadStatus.unread.rawValue,
      ]
    ]

    let page = try await seriesService.getSeriesList(
      search: SeriesSearch(condition: condition),
      unpaged: true
    )

    return page.content
  }

  private func fetchTotalBooks(libraryId: String?) async throws -> Int {
    let search: BookSearch

    if let libraryId {
      let condition: [String: Any] = [
        "libraryId": [
          "operator": "is",
          "value": libraryId,
        ]
      ]
      search = BookSearch(condition: condition)
    } else {
      search = BookSearch()
    }

    let page = try await bookService.getBooksList(
      search: search,
      page: 0,
      size: 1
    )

    return page.totalElements
  }

  // MARK: - Aggregation

  private func buildPayload(filteredBooks: [Book], readSeries: [Series], totalBooks: Int) -> ReadingStatsPayload {
    let booksWithProgress = filteredBooks.filter { $0.readProgress != nil }
    let completedBooks = filteredBooks.filter { $0.readProgress?.completed == true }

    let totalPagesRead = completedBooks.reduce(0.0) { partial, book in
      partial + Double(book.readProgress?.page ?? 0)
    }

    let averagePagesPerBook = completedBooks.isEmpty ? 0 : (totalPagesRead / Double(completedBooks.count)).rounded()
    let estimatedReadingHours = (totalPagesRead / 2 / 60).rounded()

    let readDates = completedBooks.compactMap { $0.readProgress?.readDate }
    let lastReadDate = readDates.max()
    let uniqueReadingDays = Set(readDates.map { Self.dayKeyFormatter.string(from: $0) })

    let summary = ReadingStatsSummary(
      totalBooks: Double(totalBooks),
      booksStartedReading: Double(booksWithProgress.count),
      booksCompletedReading: Double(completedBooks.count),
      totalPagesRead: totalPagesRead,
      averagePagesPerBook: averagePagesPerBook,
      readingDays: Double(uniqueReadingDays.count),
      estimatedReadingHours: estimatedReadingHours,
      lastReadAt: lastReadDate.map { Self.isoDateTimeFormatter.string(from: $0) }
    )

    let statusDistribution = buildStatusDistribution(
      totalBooks: totalBooks,
      filteredBooks: filteredBooks,
      completedBooks: completedBooks
    )

    let dailyDistribution = buildDailyDistribution(completedBooks: completedBooks)
    let hourlyDistribution = buildHourlyDistribution(completedBooks: completedBooks)
    let readingTimeSeries = buildReadingTimeSeries(completedBooks: completedBooks)

    let dimensions = buildDimensions(completedBooks: completedBooks, readSeries: readSeries)

    return ReadingStatsPayload(
      summary: summary,
      statusDistribution: statusDistribution,
      dailyDistribution: dailyDistribution,
      hourlyDistribution: hourlyDistribution,
      readingTimeSeries: readingTimeSeries,
      topAuthors: dimensions.topAuthors,
      topGenres: dimensions.topGenres,
      topTags: dimensions.topTags,
      genreDistribution: dimensions.genreDistribution,
      tagDistribution: dimensions.tagDistribution,
      generatedAt: Self.isoDateTimeFormatter.string(from: Date())
    )
  }

  private func buildStatusDistribution(
    totalBooks: Int,
    filteredBooks: [Book],
    completedBooks: [Book]
  ) -> [ReadingStatsItem] {
    let completedCount = completedBooks.count
    let inProgressCount = filteredBooks.filter { book in
      guard let progress = book.readProgress else { return false }
      return progress.completed == false
    }.count
    let unreadCount = max(totalBooks - filteredBooks.count, 0)

    return [
      ReadingStatsItem(name: String(localized: "readStatus.read"), value: Double(completedCount)),
      ReadingStatsItem(name: String(localized: "readStatus.inProgress"), value: Double(inProgressCount)),
      ReadingStatsItem(name: String(localized: "readStatus.unread"), value: Double(unreadCount)),
    ].filter { $0.value > 0 }
  }

  private func buildDailyDistribution(completedBooks: [Book]) -> [ReadingStatsItem] {
    let calendar = Calendar.current
    let weekdaySymbols = calendar.shortWeekdaySymbols

    var counts = Array(repeating: 0, count: 7)
    for book in completedBooks {
      guard let readDate = book.readProgress?.readDate else { continue }
      let weekday = calendar.component(.weekday, from: readDate)
      guard weekday >= 1 && weekday <= 7 else { continue }
      counts[weekday - 1] += 1
    }

    return weekdaySymbols.enumerated().map { index, symbol in
      ReadingStatsItem(name: symbol, value: Double(counts[index]))
    }
  }

  private func buildHourlyDistribution(completedBooks: [Book]) -> [ReadingStatsItem] {
    let calendar = Calendar.current
    var counts = Array(repeating: 0, count: 24)

    for book in completedBooks {
      guard let readDate = book.readProgress?.readDate else { continue }
      let hour = calendar.component(.hour, from: readDate)
      guard hour >= 0 && hour < 24 else { continue }
      counts[hour] += 1
    }

    return counts.enumerated().map { hour, count in
      ReadingStatsItem(name: String(format: "%d:00", hour), value: Double(count))
    }
  }

  private func buildReadingTimeSeries(completedBooks: [Book]) -> [ReadingStatsTimePoint] {
    guard !completedBooks.isEmpty else { return [] }

    let today = Date()
    let startDate =
      completedBooks
      .compactMap { $0.readProgress?.readDate }
      .min()
      .map { Calendar.current.startOfDay(for: $0) }
      ?? Calendar.current.startOfDay(for: today)

    var hoursByDay: [String: Double] = [:]
    for book in completedBooks {
      guard let progress = book.readProgress else { continue }
      let dayKey = Self.dayKeyFormatter.string(from: progress.readDate)
      let hours = Double(progress.page) / 2 / 60
      hoursByDay[dayKey, default: 0] += hours
    }

    var points: [ReadingStatsTimePoint] = []
    var cursor = startDate
    let endDate = Calendar.current.startOfDay(for: today)

    while cursor <= endDate {
      let dayKey = Self.dayKeyFormatter.string(from: cursor)
      points.append(
        ReadingStatsTimePoint(
          name: dayKey,
          value: hoursByDay[dayKey, default: 0],
          dateString: dayKey
        )
      )
      guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = nextDay
    }

    return points
  }

  private func buildDimensions(completedBooks: [Book], readSeries: [Series]) -> ReadingStatsDimensions {
    let seriesById = Dictionary(uniqueKeysWithValues: readSeries.map { ($0.id, $0) })
    let booksBySeries = Dictionary(grouping: completedBooks, by: \.seriesId)

    var authorCounts: [String: Int] = [:]
    var genreCounts: [String: Int] = [:]
    var tagCounts: [String: Int] = [:]

    for (seriesId, books) in booksBySeries {
      let series = seriesById[seriesId]

      if let genres = series?.metadata.genres {
        for genre in genres where !genre.isEmpty {
          genreCounts[genre, default: 0] += 1
        }
      }

      var authors = Set<String>()
      var tags = Set<String>()

      if let seriesAuthors = series?.booksMetadata.authors {
        for author in seriesAuthors where !author.name.isEmpty {
          authors.insert(author.name)
        }
      }

      if let seriesTags = series?.metadata.tags {
        for tag in seriesTags where !tag.isEmpty {
          tags.insert(tag)
        }
      }

      for book in books {
        if let bookAuthors = book.metadata.authors {
          for author in bookAuthors where !author.name.isEmpty {
            authors.insert(author.name)
          }
        }

        if let bookTags = book.metadata.tags {
          for tag in bookTags where !tag.isEmpty {
            tags.insert(tag)
          }
        }
      }

      for author in authors {
        authorCounts[author, default: 0] += 1
      }

      for tag in tags {
        tagCounts[tag, default: 0] += 1
      }
    }

    let topAuthors = sortedItems(from: authorCounts)
    let topGenres = sortedItems(from: genreCounts)
    let topTags = sortedItems(from: tagCounts)

    return ReadingStatsDimensions(
      topAuthors: topAuthors,
      topGenres: topGenres,
      topTags: topTags,
      genreDistribution: makeDistribution(from: topGenres),
      tagDistribution: makeDistribution(from: topTags)
    )
  }

  private func sortedItems(from counts: [String: Int]) -> [ReadingStatsItem] {
    counts
      .map { ReadingStatsItem(name: $0.key, value: Double($0.value)) }
      .sorted {
        if $0.value == $1.value {
          return $0.name.localizedCompare($1.name) == .orderedAscending
        }
        return $0.value > $1.value
      }
  }

  private func makeDistribution(from items: [ReadingStatsItem], topCount: Int = 17) -> [ReadingStatsItem] {
    guard items.count > topCount else { return items }

    let fixedItems = Array(items.prefix(topCount))
    let otherValue = items.dropFirst(topCount).reduce(0.0) { partial, item in
      partial + item.value
    }

    return fixedItems + [ReadingStatsItem(name: String(localized: "Other"), value: otherValue)]
  }

  private func normalizeLibraryId(_ libraryId: String?) -> String? {
    guard let libraryId else { return nil }
    let trimmed = libraryId.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static let dayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let isoDateTimeFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}

private struct ReadingStatsDimensions {
  let topAuthors: [ReadingStatsItem]
  let topGenres: [ReadingStatsItem]
  let topTags: [ReadingStatsItem]
  let genreDistribution: [ReadingStatsItem]
  let tagDistribution: [ReadingStatsItem]
}
