//
// KMReaderSchemaV5.swift
//
//

import Foundation
import SwiftData

enum KMReaderSchemaV5: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(5, 0, 0)
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
