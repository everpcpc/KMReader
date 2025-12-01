//
//  ReaderManifestService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import UniformTypeIdentifiers

struct ReaderManifestService {
  struct Result {
    let pages: [BookPage]
    let tocEntries: [ReaderTOCEntry]
    let pageResources: [Int: ReaderPageResource]
  }

  let bookId: String
  let logger: Logger

  func resolve(manifest: DivinaManifest) async -> Result {
    var resolvedPages: [BookPage] = []
    var hrefToPageIndex: [String: Int] = [:]
    var resources: [Int: ReaderPageResource] = [:]

    for (manifestIndex, resource) in manifest.readingOrder.enumerated() {
      guard let canonicalURL = resolvedManifestURL(from: resource.href) else {
        logger.error("❌ Invalid manifest href at index \(manifestIndex) for book \(self.bookId)")
        continue
      }

      let pageIndex = resolvedPages.count

      if let result = resolveManifestEntry(
        resource: resource,
        manifestIndex: manifestIndex,
        pageIndex: pageIndex,
        canonicalURL: canonicalURL
      ) {
        resolvedPages.append(result.page)
        resources[result.page.number] = result.resource
        hrefToPageIndex[canonicalURL.absoluteString] = pageIndex
      }
    }

    let tocEntries = buildTOCEntries(
      manifestTOC: manifest.toc,
      hrefPageMap: hrefToPageIndex
    )

    return Result(pages: resolvedPages, tocEntries: tocEntries, pageResources: resources)
  }

  private func resolveManifestEntry(
    resource: DivinaManifestResource,
    manifestIndex: Int,
    pageIndex: Int,
    canonicalURL: URL
  ) -> PageBuildResult? {
    do {
      return try buildBookPage(
        resource: resource,
        pageIndex: pageIndex,
        resourceURL: canonicalURL
      )
    } catch {
      logger.error(
        "❌ Failed to resolve manifest entry \(manifestIndex) for book \(self.bookId): \(error.localizedDescription)"
      )
      return nil
    }
  }

  private func buildBookPage(
    resource: DivinaManifestResource,
    pageIndex: Int,
    resourceURL: URL
  ) throws -> PageBuildResult {
    var mediaType = ReaderMediaHelper.normalizedMimeType(resource.type)
    let isXHTML = isXHTMLResource(type: mediaType, url: resourceURL)

    var downloadURL: URL?
    let pageResource: ReaderPageResource

    if isXHTML {
      pageResource = .xhtml(resourceURL)
      if mediaType.isEmpty {
        mediaType = "application/xhtml+xml"
      }
    } else {
      if mediaType.isEmpty {
        mediaType = ReaderMediaHelper.guessMediaType(for: resourceURL)
      }

      guard mediaType.hasPrefix("image/") else {
        throw AppErrorType.manifestUnsupportedType(mediaType)
      }

      downloadURL = resourceURL
      pageResource = .direct(resourceURL)
    }

    let resolvedURL = downloadURL ?? resourceURL
    let resolvedFileName =
      resolvedURL.lastPathComponent.isEmpty
      ? "page-\(pageIndex + 1)" : resolvedURL.lastPathComponent

    let page = BookPage(
      number: pageIndex + 1,
      fileName: resolvedFileName,
      mediaType: mediaType,
      width: resource.width,
      height: resource.height,
      sizeBytes: nil,
      size: "",
      downloadURL: downloadURL
    )

    return PageBuildResult(page: page, resource: pageResource)
  }

  private func isXHTMLResource(type: String, url: URL) -> Bool {
    if type == "application/xhtml+xml" || type == "text/html" || type == "application/xml" {
      return true
    }
    let ext = url.pathExtension.lowercased()
    return ["xhtml", "html", "htm", "xml", "svg"].contains(ext)
  }

  private func buildTOCEntries(
    manifestTOC: [DivinaManifestLink]?,
    hrefPageMap: [String: Int]
  ) -> [ReaderTOCEntry] {
    guard let manifestTOC, !manifestTOC.isEmpty else { return [] }
    var entries: [ReaderTOCEntry] = []

    for item in manifestTOC {
      guard
        let resolvedURL = resolvedManifestURL(from: item.href),
        let pageIndex = hrefPageMap[resolvedURL.absoluteString]
      else {
        continue
      }

      let trimmedTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let title =
        trimmedTitle.isEmpty
        ? String(
          format: NSLocalizedString("Page %d", comment: "Fallback TOC title"), pageIndex + 1)
        : trimmedTitle

      entries.append(ReaderTOCEntry(title: title, pageIndex: pageIndex))
    }

    return entries
  }

  private func resolvedManifestURL(from href: String) -> URL? {
    guard !href.isEmpty else { return nil }
    if let absoluteURL = URL(string: href), absoluteURL.scheme != nil {
      return absoluteURL
    }
    guard !AppConfig.serverURL.isEmpty, let baseURL = URL(string: AppConfig.serverURL) else {
      return nil
    }
    if let relativeURL = URL(string: href, relativeTo: baseURL) {
      return relativeURL.absoluteURL
    }
    return nil
  }
}

struct PageBuildResult {
  let page: BookPage
  let resource: ReaderPageResource
}

enum ReaderPageResource {
  case direct(URL)
  case xhtml(URL)
}
