//
//  DownloadActivityAttributes.swift
//  KMReader
//
//  Shared ActivityAttributes for download progress Live Activity.
//  This file must be included in both the main app and widget extension targets.
//

import Foundation

#if canImport(ActivityKit)
  import ActivityKit

  public struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      /// Series title
      public var seriesTitle: String
      /// Book info (e.g. "#1 - Chapter Title")
      public var bookInfo: String
      /// Download progress (0.0 - 1.0)
      public var progress: Double
      /// Number of pending books in queue
      public var pendingCount: Int
      /// Number of failed downloads
      public var failedCount: Int

      public init(
        seriesTitle: String, bookInfo: String, progress: Double, pendingCount: Int,
        failedCount: Int
      ) {
        self.seriesTitle = seriesTitle
        self.bookInfo = bookInfo
        self.progress = progress
        self.pendingCount = pendingCount
        self.failedCount = failedCount
      }
    }

    /// Total number of books to download in this session
    public var totalBooks: Int

    public init(totalBooks: Int) {
      self.totalBooks = totalBooks
    }
  }
#endif
