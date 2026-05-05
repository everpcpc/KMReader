//
// KMReaderSchemaV4.swift
//
//

import SwiftData

enum KMReaderSchemaV4: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(4, 0, 0)
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
