//
//  Metrics.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Metric: Codable {
  let name: String
  let description: String?
  let baseUnit: String?
  let measurements: [Measurement]
  let availableTags: [TagInfo]?

  struct Measurement: Codable {
    let statistic: String
    let value: Double
  }

  struct TagInfo: Codable {
    let tag: String
    let values: [String]
  }
}

struct MetricTag: Codable {
  let key: String
  let value: String
}

enum MetricName: String {
  case booksFileSize = "komga.books.filesize"
  case series = "komga.series"
  case books = "komga.books"
  case collections = "komga.collections"
  case readlists = "komga.readlists"
  case sidecars = "komga.sidecars"
  case tasksExecution = "komga.tasks.execution"
}
