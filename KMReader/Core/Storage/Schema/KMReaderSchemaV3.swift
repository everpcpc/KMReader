//
// KMReaderSchemaV3.swift
//
//

import SwiftData

enum KMReaderSchemaV3: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(3, 0, 0)
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
