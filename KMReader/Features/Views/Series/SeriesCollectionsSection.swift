//
//  SeriesCollectionsSection.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SeriesCollectionsSection: View {
  @Query private var komgaCollections: [KomgaCollection]

  init(collectionIds: [String]) {
    let instanceId = AppConfig.current.instanceId
    _komgaCollections = Query(
      filter: #Predicate<KomgaCollection> {
        $0.instanceId == instanceId && collectionIds.contains($0.collectionId)
      })
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
                Label(collection.name, systemImage: "square.grid.2x2")
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
