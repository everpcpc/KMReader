//
// KMReaderSchemaV2.swift
//
//

import SwiftData

enum KMReaderSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [
      KomgaInstance.self,
      KomgaLibrary.self,
      KomgaSeries.self,
      KomgaBook.self,
      KomgaCollection.self,
      KomgaReadList.self,
      CustomFont.self,
      PendingProgress.self,
      SavedFilter.self,
      EpubThemePreset.self,
    ]
  }
}
