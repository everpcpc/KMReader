//
//  QuickActionService.swift
//  KMReader
//

import Foundation

#if os(iOS)
  import UIKit

  enum QuickActionService {
    static func handleShortcut(_ item: UIApplicationShortcutItem) {
      switch item.type {
      case "com.everpcpc.Komga.continueReading":
        Task { @MainActor in
          let books = await DatabaseOperator.shared.fetchKeepReadingBooksForWidget(
            instanceId: AppConfig.current.instanceId,
            libraryIds: AppConfig.dashboard.libraryIds,
            limit: 1)
          if let book = books.first {
            DeepLinkRouter.shared.pendingDeepLink = .book(bookId: book.id)
          }
        }
      case "com.everpcpc.Komga.search":
        Task { @MainActor in
          DeepLinkRouter.shared.pendingDeepLink = .search
        }
      case "com.everpcpc.Komga.downloads":
        Task { @MainActor in
          DeepLinkRouter.shared.pendingDeepLink = .downloads
        }
      default:
        break
      }
    }
  }
#endif
