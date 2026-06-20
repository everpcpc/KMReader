//
// SeriesCollectionsSection.swift
//
//

import SwiftUI

struct SeriesCollectionsSection: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  let collectionIds: [String]

  @State private var collections: [SidebarCollectionItem] = []

  private var collectionIdsKey: String {
    collectionIds.sorted().joined(separator: ",")
  }

  var body: some View {
    Group {
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
                value: NavDestination.collectionDetail(collectionId: collection.collectionId)
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
    .task(id: "\(current.instanceId)|\(collectionIdsKey)") {
      await loadCollections()
    }
  }

  private func loadCollections() async {
    let instanceId = current.instanceId
    guard !instanceId.isEmpty, !collectionIds.isEmpty else {
      if !collections.isEmpty {
        withAnimation {
          collections = []
        }
      }
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      let loadedCollections = try await database.fetchSidebarCollections(
        instanceId: instanceId,
        collectionIds: Set(collectionIds)
      )
      if collections != loadedCollections {
        withAnimation {
          collections = loadedCollections
        }
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
