//
//  CustomFontStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import CoreText
#endif
import Foundation
import SwiftData

@MainActor
final class CustomFontStore {
  static let shared = CustomFontStore()

  private var container: ModelContainer?

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
  }

  private func makeContext() throws -> ModelContext {
    guard let container else {
      throw AppErrorType.storageNotConfigured(message: "ModelContainer is not configured")
    }
    return ModelContext(container)
  }

  func fetchCustomFonts() -> [String] {
    guard let container else { return [] }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CustomFont>(
      sortBy: [SortDescriptor(\CustomFont.name, order: .forward)]
    )
    guard let fonts = try? context.fetch(descriptor) else { return [] }
    return fonts.map { $0.name }
  }

  func customFontCount() -> Int {
    guard let container else { return 0 }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CustomFont>()
    return (try? context.fetchCount(descriptor)) ?? 0
  }

  func getFontPath(for fontName: String) -> String? {
    guard let container else { return nil }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CustomFont>(
      predicate: #Predicate<CustomFont> { font in
        font.name == fontName
      }
    )
    guard let font = try? context.fetch(descriptor).first else { return nil }
    guard let relativePath = font.path else { return nil }

    // Resolve relative path to absolute path using FontFileManager
    return FontFileManager.resolvePath(relativePath)
  }
}
