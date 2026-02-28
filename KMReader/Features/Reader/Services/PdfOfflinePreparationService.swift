//
// PdfOfflinePreparationService.swift
//
//

import Foundation
import ImageIO

#if os(iOS) || os(macOS)
  #if os(iOS)
    import UIKit
  #elseif os(macOS)
    import AppKit
  #endif
  import PDFKit
#endif

actor PdfOfflinePreparationService {
  private struct RenderedPageData: Sendable {
    let data: Data
    let pixelWidth: Int
    let pixelHeight: Int
  }

  struct PreparationResult: Sendable {
    let pages: [BookPage]
    let tableOfContents: [ReaderTOCEntry]
    let renderedImageCount: Int
    let reusedImageCount: Int
    let skippedImageCount: Int
  }

  static let shared = PdfOfflinePreparationService()

  private let logger = AppLogger(.reader)
  private var preparationTasks: [String: Task<PreparationResult?, Never>] = [:]

  private init() {}

  func prepare(
    instanceId: String,
    bookId: String,
    documentURL: URL,
    forceRebuildMetadata: Bool = false
  ) async -> PreparationResult? {
    let taskKey = "\(instanceId)|\(bookId)"
    logger.debug("🚧 Start offline PDF preparation for book \(bookId), instance \(instanceId)")
    let renderQuality = AppConfig.pdfOfflineRenderQuality
    let completionFlag = OfflineManager.pdfPreparationCompletionFlag(renderQuality: renderQuality)

    let existingStamp = await OfflineManager.shared.readOfflinePDFPreparationStamp(
      instanceId: instanceId,
      bookId: bookId
    )

    if !forceRebuildMetadata,
      existingStamp == completionFlag
    {
      logger.debug("⏭️ Skip PDF preparation because completion flag exists for book \(bookId)")
      return nil
    }

    if let existingTask = preparationTasks[taskKey] {
      logger.debug("♻️ Reusing existing offline PDF preparation task for book \(bookId)")
      return await existingTask.value
    }

    let task = Task(priority: .userInitiated) {
      await Self.prepareDocument(
        instanceId: instanceId,
        bookId: bookId,
        documentURL: documentURL,
        forceRerenderImages: existingStamp != completionFlag,
        renderQuality: renderQuality
      )
    }

    preparationTasks[taskKey] = task
    let result = await task.value
    preparationTasks.removeValue(forKey: taskKey)

    if let result {
      let totalPages = result.pages.count
      let shouldWriteStamp =
        totalPages > 0
        && result.skippedImageCount == 0
        && (result.renderedImageCount + result.reusedImageCount) == totalPages
      if shouldWriteStamp {
        await OfflineManager.shared.writeOfflinePDFPreparationStamp(
          instanceId: instanceId,
          bookId: bookId,
          stamp: completionFlag
        )
      } else {
        logger.debug(
          "⚠️ Skip writing PDF preparation stamp for book \(bookId), rendered=\(result.renderedImageCount), reused=\(result.reusedImageCount), skipped=\(result.skippedImageCount), pages=\(totalPages)"
        )
      }

      logger.debug(
        "✅ Prepared offline PDF assets for book \(bookId), pages=\(result.pages.count), toc=\(result.tableOfContents.count), rendered=\(result.renderedImageCount), reused=\(result.reusedImageCount), skipped=\(result.skippedImageCount)"
      )
    } else {
      logger.warning("⚠️ Failed to prepare offline PDF assets for book \(bookId)")
    }
    return result
  }

  #if os(iOS) || os(macOS)
    nonisolated private static func prepareDocument(
      instanceId: String,
      bookId: String,
      documentURL: URL,
      forceRerenderImages: Bool,
      renderQuality: PdfOfflineRenderQuality
    ) async -> PreparationResult? {
      await Task.detached(priority: .userInitiated) {
        guard let document = PDFDocument(url: documentURL) else {
          return nil
        }

        let totalPages = document.pageCount
        guard totalPages > 0 else {
          return PreparationResult(
            pages: [],
            tableOfContents: [],
            renderedImageCount: 0,
            reusedImageCount: 0,
            skippedImageCount: 0
          )
        }

        var pages: [BookPage] = []
        pages.reserveCapacity(totalPages)
        var renderedImageCount = 0
        var reusedImageCount = 0
        var skippedImageCount = 0

        if forceRerenderImages {
          await OfflineManager.shared.clearOfflinePageImages(instanceId: instanceId, bookId: bookId)
        }

        for pageIndex in 0..<totalPages {
          if Task.isCancelled {
            return nil
          }

          let pageNumber = pageIndex + 1
          let fileName = "page-\(pageNumber).png"
          guard let pdfPage = document.page(at: pageIndex) else {
            let bookPage = BookPage(
              number: pageNumber,
              fileName: fileName,
              mediaType: "image/png",
              width: nil,
              height: nil,
              sizeBytes: nil,
              size: "",
              downloadURL: nil
            )
            pages.append(bookPage)
            skippedImageCount += 1
            continue
          }

          let fallbackPixelSize = targetPixelSize(for: pdfPage, renderQuality: renderQuality)

          if let offlineURL = await OfflineManager.shared.getOfflinePageImageURL(
            instanceId: instanceId,
            bookId: bookId,
            pageNumber: pageNumber,
            fileExtension: "png"
          ) {
            let existingPixelSize = imagePixelSize(at: offlineURL) ?? fallbackPixelSize
            let bookPage = BookPage(
              number: pageNumber,
              fileName: fileName,
              mediaType: "image/png",
              width: existingPixelSize.map { Int($0.width) },
              height: existingPixelSize.map { Int($0.height) },
              sizeBytes: nil,
              size: "",
              downloadURL: nil
            )
            pages.append(bookPage)
            reusedImageCount += 1
            continue
          }

          guard let pageData = renderPageData(page: pdfPage, renderQuality: renderQuality) else {
            let bookPage = BookPage(
              number: pageNumber,
              fileName: fileName,
              mediaType: "image/png",
              width: fallbackPixelSize.map { Int($0.width) },
              height: fallbackPixelSize.map { Int($0.height) },
              sizeBytes: nil,
              size: "",
              downloadURL: nil
            )
            pages.append(bookPage)
            skippedImageCount += 1
            continue
          }

          let bookPage = BookPage(
            number: pageNumber,
            fileName: fileName,
            mediaType: "image/png",
            width: pageData.pixelWidth,
            height: pageData.pixelHeight,
            sizeBytes: Int64(pageData.data.count),
            size: "",
            downloadURL: nil
          )
          pages.append(bookPage)

          if await OfflineManager.shared.storeOfflinePageImage(
            instanceId: instanceId,
            bookId: bookId,
            pageNumber: pageNumber,
            fileExtension: "png",
            data: pageData.data
          ) != nil {
            renderedImageCount += 1
          } else {
            skippedImageCount += 1
          }
        }

        let toc = buildTableOfContents(from: document)
        return PreparationResult(
          pages: pages,
          tableOfContents: toc,
          renderedImageCount: renderedImageCount,
          reusedImageCount: reusedImageCount,
          skippedImageCount: skippedImageCount
        )
      }.value
    }

    nonisolated private static func renderPageData(
      page: PDFPage,
      renderQuality: PdfOfflineRenderQuality
    ) -> RenderedPageData? {
      let pageBounds = page.bounds(for: .mediaBox).standardized
      guard let targetPixelSize = targetPixelSize(for: page, renderQuality: renderQuality) else {
        return nil
      }

      let pixelWidth = Int(targetPixelSize.width)
      let pixelHeight = Int(targetPixelSize.height)
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

      guard
        let context = CGContext(
          data: nil,
          width: pixelWidth,
          height: pixelHeight,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: bitmapInfo
        )
      else {
        return nil
      }

      context.interpolationQuality = .high
      context.setShouldAntialias(true)
      context.setAllowsAntialiasing(true)
      context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

      let scaleX = CGFloat(pixelWidth) / max(pageBounds.width, 1)
      let scaleY = CGFloat(pixelHeight) / max(pageBounds.height, 1)
      context.translateBy(x: 0, y: CGFloat(pixelHeight))
      context.scaleBy(x: scaleX, y: -scaleY)
      context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
      page.draw(with: .mediaBox, to: context)

      guard let cgImage = context.makeImage() else {
        return nil
      }

      #if os(iOS)
        let image = UIImage(cgImage: cgImage)
      #elseif os(macOS)
        let image = NSImage(
          cgImage: cgImage,
          size: NSSize(width: pixelWidth, height: pixelHeight)
        )
      #endif

      guard let data = PlatformHelper.pngData(from: image) else {
        return nil
      }

      return RenderedPageData(
        data: data,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight
      )
    }

    nonisolated private static func targetPixelSize(
      for page: PDFPage,
      renderQuality: PdfOfflineRenderQuality
    ) -> CGSize? {
      let pageBounds = page.bounds(for: .mediaBox).standardized
      let width = max(pageBounds.width, 1)
      let height = max(pageBounds.height, 1)
      let maxDimension = max(width, height)
      guard maxDimension > 0 else {
        return nil
      }

      // PDF page bounds are measured in points at 72 DPI. Rendering at up to 4x points
      // keeps text sharp on Retina screens while respecting the configured long-edge cap.
      let renderScale = min(4.0, renderQuality.maxLongEdge / maxDimension)
      return CGSize(
        width: max(1, (width * renderScale).rounded(.up)),
        height: max(1, (height * renderScale).rounded(.up))
      )
    }

    nonisolated private static func imagePixelSize(at fileURL: URL) -> CGSize? {
      let options = [kCGImageSourceShouldCache: false] as CFDictionary
      guard
        let source = CGImageSourceCreateWithURL(fileURL as CFURL, options),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
        let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
        width > 0,
        height > 0
      else {
        return nil
      }

      return CGSize(width: width, height: height)
    }

    nonisolated private static func buildTableOfContents(from document: PDFDocument) -> [ReaderTOCEntry] {
      guard let outlineRoot = document.outlineRoot else { return [] }

      var entries: [ReaderTOCEntry] = []
      for index in 0..<outlineRoot.numberOfChildren {
        guard let child = outlineRoot.child(at: index),
          let entry = buildTOCEntry(from: child, in: document)
        else {
          continue
        }
        entries.append(entry)
      }
      return entries
    }

    nonisolated private static func buildTOCEntry(
      from outline: PDFOutline,
      in document: PDFDocument
    ) -> ReaderTOCEntry? {
      var childEntries: [ReaderTOCEntry] = []
      for index in 0..<outline.numberOfChildren {
        guard let child = outline.child(at: index),
          let childEntry = buildTOCEntry(from: child, in: document)
        else {
          continue
        }
        childEntries.append(childEntry)
      }

      let ownPageIndex = pageIndex(from: outline, in: document)
      let fallbackPageIndex = childEntries.first?.pageIndex
      guard let pageIndex = ownPageIndex ?? fallbackPageIndex else { return nil }

      let trimmedLabel = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let title = trimmedLabel.isEmpty ? localizedPageLabel(pageIndex + 1) : trimmedLabel
      return ReaderTOCEntry(
        title: title,
        pageIndex: pageIndex,
        children: childEntries.isEmpty ? nil : childEntries
      )
    }

    nonisolated private static func pageIndex(from outline: PDFOutline, in document: PDFDocument) -> Int? {
      if let destination = outline.destination,
        let page = destination.page
      {
        let index = document.index(for: page)
        guard index != NSNotFound, index >= 0, index < document.pageCount else {
          return nil
        }
        return index
      }

      if let action = outline.action as? PDFActionGoTo,
        let page = action.destination.page
      {
        let index = document.index(for: page)
        guard index != NSNotFound, index >= 0, index < document.pageCount else {
          return nil
        }
        return index
      }

      return nil
    }

    nonisolated private static func localizedPageLabel(_ pageNumber: Int) -> String {
      let format = String(localized: "Page %d", bundle: .main, comment: "Fallback TOC title")
      return String.localizedStringWithFormat(format, pageNumber)
    }
  #else
    nonisolated private static func prepareDocument(
      instanceId _: String,
      bookId _: String,
      documentURL _: URL,
      forceRerenderImages _: Bool,
      renderQuality _: PdfOfflineRenderQuality
    ) async -> PreparationResult? {
      nil
    }
  #endif
}
