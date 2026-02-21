//
// SeriesCollectionsSection.swift
//
//

import SQLiteData
import SwiftUI

struct SeriesCollectionsSection: View {
  @FetchAll private var komgaCollections: [KomgaCollectionRecord]

  init(collectionIds: [String]) {
    let instanceId = AppConfig.current.instanceId
    if collectionIds.isEmpty {
      _komgaCollections = FetchAll(
        KomgaCollectionRecord.where { $0.id.eq("__none__") }
      )
    } else {
      _komgaCollections = FetchAll(
        KomgaCollectionRecord.where {
          $0.instanceId.eq(instanceId) && $0.collectionId.in(collectionIds)
        }
      )
    }
  }

  private var collections: [SeriesCollection] {
    komgaCollections.map { $0.toCollection() }
  }

  var body: some View {
    if !collections.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Text("Collections")
            .font(.headline)
        }
        .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          ForEach(collections) { collection in
            NavigationLink(
              value: NavDestination.collectionDetail(collectionId: collection.id)
            ) {
              HStack {
                Label(collection.name, systemImage: ContentIcon.collection)
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              .padding()
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(16)
            }.adaptiveButtonStyle(.plain)
          }
        }
      }
    }
  }
}
