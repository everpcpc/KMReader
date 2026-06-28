//
// ThumbnailCacheMissingResult.swift
//
//

import Foundation

nonisolated enum ThumbnailCacheMissingResult: Sendable {
  case cached
  case stored
  case cacheLimitReached
}
