//
// Metrics.swift
//
//

import Foundation

nonisolated struct Metric: Codable, Sendable {
  let name: String
  let description: String?
  let baseUnit: String?
  let measurements: [Measurement]
  let availableTags: [TagInfo]?

  struct Measurement: Codable, Sendable {
    let statistic: String
    let value: Double
  }

  struct TagInfo: Codable, Sendable {
    let tag: String
    let values: [String]
  }
}

nonisolated struct MetricTag: Codable, Sendable {
  let key: String
  let value: String
}

nonisolated enum MetricName: String, Sendable {
  case booksFileSize = "komga.books.filesize"
  case series = "komga.series"
  case books = "komga.books"
  case collections = "komga.collections"
  case readlists = "komga.readlists"
  case sidecars = "komga.sidecars"
  case tasksExecution = "komga.tasks.execution"
}
