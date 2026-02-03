//
//  KomgaWebLinkBuilder.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum KomgaWebLinkBuilder {
  static func series(serverURL: String, seriesId: String) -> URL? {
    build(serverURL: serverURL, path: "/#/series/\(seriesId)")
  }

  static func oneshot(serverURL: String, seriesId: String) -> URL? {
    series(serverURL: serverURL, seriesId: seriesId)
  }

  static func book(serverURL: String, bookId: String) -> URL? {
    build(serverURL: serverURL, path: "/#/book/\(bookId)")
  }

  static func collection(serverURL: String, collectionId: String) -> URL? {
    build(serverURL: serverURL, path: "/#/collections/\(collectionId)")
  }

  static func readList(serverURL: String, readListId: String) -> URL? {
    build(serverURL: serverURL, path: "/#/readlists/\(readListId)")
  }

  private static func build(serverURL: String, path: String) -> URL? {
    let normalizedBase = normalizedServerURL(serverURL)
    guard !normalizedBase.isEmpty else { return nil }
    return URL(string: normalizedBase + path)
  }

  private static func normalizedServerURL(_ serverURL: String) -> String {
    var value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while value.hasSuffix("/") {
      value.removeLast()
    }
    return value
  }
}
