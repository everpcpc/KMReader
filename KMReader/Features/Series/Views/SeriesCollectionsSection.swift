//
// SeriesCollectionsSection.swift
//
//

import SwiftUI

struct SeriesCollectionsSection: View {
  let collections: [SidebarCollectionItem]

  // Pure display component: loading is hoisted to the parent detail view's
  // always-realized task. A self-loading .task here never fires while the body
  // renders empty inside the parent's LazyVStack (#967), and an always-present
  // zero-height anchor would collapse the surrounding stack spacing (#986).
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
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
