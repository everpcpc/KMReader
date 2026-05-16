//
// KomgaCollection.swift
//

import Foundation
import SwiftData

typealias KomgaCollection = KMReaderSchemaV6.KomgaCollection

extension KomgaCollection {
  var seriesIds: [String] {
    get { seriesIdsRaw.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    set { seriesIdsRaw = try? JSONEncoder().encode(newValue) }
  }

  func toCollection() -> SeriesCollection {
    SeriesCollection(
      id: collectionId,
      name: name,
      ordered: ordered,
      seriesIds: seriesIds,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      filtered: filtered
    )
  }
}
