//
//  DeepLinkRouter.swift
//  KMReader
//

import Foundation
import Observation

enum DeepLink: Equatable {
  case book(bookId: String)
  case series(seriesId: String)
  case search
  case downloads

  init?(url: URL) {
    guard url.scheme == "kmreader" else { return nil }
    let host = url.host()
    let pathId = url.pathComponents.dropFirst().first

    switch host {
    case "book":
      guard let id = pathId else { return nil }
      self = .book(bookId: id)
    case "series":
      guard let id = pathId else { return nil }
      self = .series(seriesId: id)
    case "search":
      self = .search
    case "downloads":
      self = .downloads
    default:
      return nil
    }
  }
}

@MainActor
@Observable
final class DeepLinkRouter {
  static let shared = DeepLinkRouter()

  var pendingDeepLink: DeepLink?

  private init() {}

  func handle(url: URL) {
    if let link = DeepLink(url: url) {
      pendingDeepLink = link
    }
  }
}
