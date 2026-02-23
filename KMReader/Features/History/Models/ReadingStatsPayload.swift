//
// ReadingStatsPayload.swift
//
//

import Foundation

nonisolated struct ReadingStatsPayload: Codable, Equatable, Sendable {
  let summary: ReadingStatsSummary
  let statusDistribution: [ReadingStatsItem]
  let dailyDistribution: [ReadingStatsItem]
  let hourlyDistribution: [ReadingStatsItem]
  let readingTimeSeries: [ReadingStatsTimePoint]
  let topAuthors: [ReadingStatsItem]
  let topGenres: [ReadingStatsItem]
  let topTags: [ReadingStatsItem]
  let genreDistribution: [ReadingStatsItem]
  let tagDistribution: [ReadingStatsItem]
  let generatedAt: String?

  init(
    summary: ReadingStatsSummary = ReadingStatsSummary(),
    statusDistribution: [ReadingStatsItem] = [],
    dailyDistribution: [ReadingStatsItem] = [],
    hourlyDistribution: [ReadingStatsItem] = [],
    readingTimeSeries: [ReadingStatsTimePoint] = [],
    topAuthors: [ReadingStatsItem] = [],
    topGenres: [ReadingStatsItem] = [],
    topTags: [ReadingStatsItem] = [],
    genreDistribution: [ReadingStatsItem] = [],
    tagDistribution: [ReadingStatsItem] = [],
    generatedAt: String? = nil
  ) {
    self.summary = summary
    self.statusDistribution = statusDistribution
    self.dailyDistribution = dailyDistribution
    self.hourlyDistribution = hourlyDistribution
    self.readingTimeSeries = readingTimeSeries
    self.topAuthors = topAuthors
    self.topGenres = topGenres
    self.topTags = topTags
    self.genreDistribution = genreDistribution
    self.tagDistribution = tagDistribution
    self.generatedAt = generatedAt
  }

  static let empty = ReadingStatsPayload()

  private enum CodingKeys: String, CodingKey {
    case summary

    case statusDistribution
    case readingStatus

    case dailyDistribution
    case readingByDay

    case hourlyDistribution
    case readingByHour

    case readingTimeSeries
    case readingTimeChart
    case chartData

    case topAuthors
    case authorWords

    case topGenres
    case genreWords

    case topTags
    case tagWords

    case genreDistribution
    case genresDistribution

    case tagDistribution
    case tagsDistribution

    case generatedAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    summary = try container.decodeIfPresent(ReadingStatsSummary.self, forKey: .summary) ?? ReadingStatsSummary()

    statusDistribution =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.statusDistribution, .readingStatus])
      ?? []

    dailyDistribution =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.dailyDistribution, .readingByDay])
      ?? []

    hourlyDistribution =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.hourlyDistribution, .readingByHour])
      ?? []

    readingTimeSeries =
      try container.decodeFirstArray(
        [ReadingStatsTimePoint].self,
        forKeys: [.readingTimeSeries, .readingTimeChart, .chartData]
      ) ?? []

    topAuthors =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.topAuthors, .authorWords])
      ?? []

    topGenres =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.topGenres, .genreWords])
      ?? []

    topTags = try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.topTags, .tagWords]) ?? []

    genreDistribution =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.genreDistribution, .genresDistribution])
      ?? []

    tagDistribution =
      try container.decodeFirstArray([ReadingStatsItem].self, forKeys: [.tagDistribution, .tagsDistribution])
      ?? []

    generatedAt = try container.decodeFirstString(forKeys: [.generatedAt, .updatedAt])
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(summary, forKey: .summary)
    try container.encode(statusDistribution, forKey: .statusDistribution)
    try container.encode(dailyDistribution, forKey: .dailyDistribution)
    try container.encode(hourlyDistribution, forKey: .hourlyDistribution)
    try container.encode(readingTimeSeries, forKey: .readingTimeSeries)
    try container.encode(topAuthors, forKey: .topAuthors)
    try container.encode(topGenres, forKey: .topGenres)
    try container.encode(topTags, forKey: .topTags)
    try container.encode(genreDistribution, forKey: .genreDistribution)
    try container.encode(tagDistribution, forKey: .tagDistribution)
    try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
  }
}
