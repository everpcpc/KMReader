//
//  QuickActionService.swift
//  KMReader
//

import Foundation

#if os(iOS)
  import UIKit

  enum QuickActionService {
    @MainActor private static var pendingShortcutItem: UIApplicationShortcutItem?

    static func handleShortcut(_ item: UIApplicationShortcutItem) {
      Task { @MainActor in
        guard let db = DatabaseOperator.shared else {
          pendingShortcutItem = item
          return
        }

        switch item.type {
        case "com.everpcpc.Komga.continueReading":
          let books = await db.fetchKeepReadingBooksForWidget(
            instanceId: AppConfig.current.instanceId,
            libraryIds: AppConfig.dashboard.libraryIds,
            limit: 1)
          if let book = books.first {
            DeepLinkRouter.shared.pendingDeepLink = .book(bookId: book.id)
          }
        case "com.everpcpc.Komga.search":
          DeepLinkRouter.shared.pendingDeepLink = .search
        case "com.everpcpc.Komga.downloads":
          DeepLinkRouter.shared.pendingDeepLink = .downloads
        default:
          break
        }
      }
    }

    @MainActor
    static func handlePendingShortcutIfNeeded() {
      guard let item = pendingShortcutItem else { return }
      pendingShortcutItem = nil
      handleShortcut(item)
    }
  }
#endif
