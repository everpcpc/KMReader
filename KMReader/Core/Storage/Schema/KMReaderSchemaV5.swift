//
// KMReaderSchemaV5.swift
//

import Foundation
import SwiftData

enum KMReaderSchemaV5: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(5, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KMReaderSchemaV6.KomgaInstance.self,
      KMReaderSchemaV6.KomgaLibrary.self,
      KMReaderSchemaV6.KomgaSeries.self,
      KMReaderSchemaV6.KomgaBook.self,
      KMReaderSchemaV6.KomgaCollection.self,
      KMReaderSchemaV6.KomgaReadList.self,
      KMReaderSchemaV6.CustomFontV1.self,
      KMReaderSchemaV6.PendingProgress.self,
      KMReaderSchemaV6.SavedFilterV1.self,
      KMReaderSchemaV6.EpubThemePresetV1.self,
    ]
  }
}
