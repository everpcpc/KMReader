//
//  ReaderXHTMLParser.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftSoup

struct ReaderXHTMLImageInfo {
  let url: URL
  let width: Int?
  let height: Int?
  let mediaType: String?
}

enum ReaderXHTMLParser {
  static nonisolated func textLength(from data: Data, baseURL: URL) -> Int? {
    // Try different encodings to decode the data
    let encodings: [String.Encoding] = [
      .utf8,
      .utf16,
      .utf16LittleEndian,
      .utf16BigEndian,
      .isoLatin1,
      .windowsCP1252,
    ]

    for encoding in encodings {
      guard let htmlString = String(data: data, encoding: encoding) else {
        continue
      }

      do {
        let doc = try SwiftSoup.parse(htmlString, baseURL.absoluteString)
        let text = try doc.text()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          return trimmed.count
        }
      } catch {
        continue
      }
    }

    return nil
  }

  static nonisolated func firstImageInfo(from data: Data, baseURL: URL) -> ReaderXHTMLImageInfo? {
    // Try different encodings to decode the data
    let encodings: [String.Encoding] = [
      .utf8,
      .utf16,
      .utf16LittleEndian,
      .utf16BigEndian,
      .isoLatin1,
      .windowsCP1252,
    ]

    for encoding in encodings {
      guard let htmlString = String(data: data, encoding: encoding) else {
        continue
      }

      do {
        let doc = try SwiftSoup.parse(htmlString, baseURL.absoluteString)

        // Try to find <img> tag first
        if let img = try doc.select("img").first() {
          if let src = try? img.attr("src"),
            !src.isEmpty,
            let resolvedURL = URL(string: src, relativeTo: baseURL)?.absoluteURL
          {
            return createImageInfo(
              element: img,
              url: resolvedURL
            )
          }
        }

        // Try to find <image> tag (SVG)
        if let image = try doc.select("image").first() {
          // Try xlink:href first, then href
          let href = (try? image.attr("xlink:href")) ?? (try? image.attr("href")) ?? ""

          if !href.isEmpty,
            let resolvedURL = URL(string: href, relativeTo: baseURL)?.absoluteURL
          {
            return createImageInfo(
              element: image,
              url: resolvedURL
            )
          }
        }
      } catch {
        // Continue to next encoding if parsing fails
        continue
      }
    }

    return nil
  }

  private static nonisolated func createImageInfo(element: Element, url: URL) -> ReaderXHTMLImageInfo {
    let width = parseDimension(from: try? element.attr("width"))
    let height = parseDimension(from: try? element.attr("height"))
    let explicitType = try? element.attr("type")
    let normalizedType = ReaderMediaHelper.normalizedMimeType(explicitType)

    return ReaderXHTMLImageInfo(
      url: url,
      width: width,
      height: height,
      mediaType: normalizedType.isEmpty ? nil : normalizedType
    )
  }

  private static nonisolated func parseDimension(from value: String?) -> Int? {
    guard let rawValue = value, !rawValue.isEmpty else { return nil }
    // Extract numeric value (handle cases like "100px", "100", "100.5")
    let filtered = rawValue.filter { "0123456789.".contains($0) }
    guard let doubleValue = Double(filtered) else {
      return nil
    }
    return Int(doubleValue.rounded())
  }
}
