//
//  CustomFontStore.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData

@MainActor
final class CustomFontStore {
  static let shared = CustomFontStore()

  private var container: ModelContainer?

  private init() {}

  func configure(with container: ModelContainer) {
    self.container = container
    migrateFromUserDefaults()
  }

  private func migrateFromUserDefaults() {
    // Migrate custom fonts from UserDefaults to SwiftData
    let userDefaultsFonts = AppConfig.customFontNames
    guard !userDefaultsFonts.isEmpty, let container else { return }

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CustomFont>()
    let existingFonts = (try? context.fetch(descriptor)) ?? []

    // Get existing font names
    let existingNames = Set(existingFonts.map { $0.name })

    // Add fonts from UserDefaults that don't exist in SwiftData
    for fontName in userDefaultsFonts {
      if !existingNames.contains(fontName) {
        let customFont = CustomFont(name: fontName)
        context.insert(customFont)
      }
    }

    // Save changes
    try? context.save()

    // Clear UserDefaults after migration
    AppConfig.customFontNames = []
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
}
