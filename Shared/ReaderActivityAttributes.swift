//
//  ReaderActivityAttributes.swift
//  KMReader
//
//  Shared ActivityAttributes for reader Live Activity.
//  This file must be included in both the main app and widget extension targets.
//

import Foundation

#if os(iOS)
  import ActivityKit

  public struct ReaderActivityAttributes: ActivityAttributes {
    public enum ReaderKind: String, Codable, Hashable {
      case divina
      case epub
      case pdf
    }

    public enum SessionState: String, Codable, Hashable {
      case reading
      case closed
    }

    public struct ContentState: Codable, Hashable {
      public var sessionState: SessionState
      public var readerKind: ReaderKind
      public var seriesTitle: String
      public var chapterTitle: String

      public init(
        sessionState: SessionState,
        readerKind: ReaderKind,
        seriesTitle: String,
        chapterTitle: String
      ) {
        self.sessionState = sessionState
        self.readerKind = readerKind
        self.seriesTitle = seriesTitle
        self.chapterTitle = chapterTitle
      }
    }

    public var bookId: String

    public init(bookId: String) {
      self.bookId = bookId
    }
  }
#endif
