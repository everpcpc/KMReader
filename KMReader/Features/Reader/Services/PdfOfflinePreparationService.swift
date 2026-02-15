//
//  PdfOfflinePreparationService.swift
//  KMReader
//

import Foundation

#if os(iOS) || os(macOS)
  import PDFKit
#endif

actor PdfOfflinePreparationService {
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

    if !forceRebuildMetadata,
      let stamp = await OfflineManager.shared.readOfflinePDFPreparationStamp(
        instanceId: instanceId,
        bookId: bookId
      ),
      stamp == OfflineManager.pdfPreparationCompletionFlag
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
        documentURL: documentURL
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
          stamp: OfflineManager.pdfPreparationCompletionFlag
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
      documentURL: URL
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

        for pageIndex in 0..<totalPages {
          if Task.isCancelled {
            return nil
          }

          let pageNumber = pageIndex + 1
          let fileName = "page-\(pageNumber).png"
          let pageBounds = document.page(at: pageIndex)?.bounds(for: .mediaBox).integral
          let bookPage = BookPage(
            number: pageNumber,
            fileName: fileName,
            mediaType: "image/png",
            width: pageBounds.map { Int(max($0.width, 1)) },
            height: pageBounds.map { Int(max($0.height, 1)) },
            sizeBytes: nil,
            size: "",
            downloadURL: nil
          )

          pages.append(bookPage)

          if await OfflineManager.shared.getOfflinePageImageURL(
            instanceId: instanceId,
            bookId: bookId,
            pageNumber: pageNumber,
            fileExtension: "png"
          ) != nil {
            reusedImageCount += 1
            continue
          }

          guard let pdfPage = document.page(at: pageIndex) else {
            skippedImageCount += 1
            continue
          }
          guard let pageData = renderPageData(page: pdfPage) else {
            skippedImageCount += 1
            continue
          }
          if await OfflineManager.shared.storeOfflinePageImage(
            instanceId: instanceId,
            bookId: bookId,
            pageNumber: pageNumber,
            fileExtension: "png",
            data: pageData
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

    nonisolated private static func renderPageData(page: PDFPage) -> Data? {
      let pageBounds = page.bounds(for: .mediaBox)
      let maxDimension: CGFloat = 2400
      let maxPageDimension = max(pageBounds.width, pageBounds.height)
      let scale = maxPageDimension > 0 ? min(1.0, maxDimension / maxPageDimension) : 1.0
      let targetSize = CGSize(
        width: max(1, pageBounds.width * scale),
        height: max(1, pageBounds.height * scale)
      )
      let image = page.thumbnail(of: targetSize, for: .mediaBox)
      return PlatformHelper.pngData(from: image)
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
      documentURL _: URL
    ) async -> PreparationResult? {
      nil
    }
  #endif
}
