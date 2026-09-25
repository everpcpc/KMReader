//
// CollectionDetailWideLayoutView.swift
//
//

import SwiftUI

/// Wide collection detail (iPad regular width, macOS wide windows): the left
/// rail carries identity and the action card (cover, hero info, series
/// count); the series list flows in the right column. Rail and content
/// scroll independently so the rail never scrolls away with the series list.
struct CollectionDetailWideLayoutView: View {
  let collection: SeriesCollection
  let item: CollectionDisplayItem?
  let collectionId: String
  let availableWidth: CGFloat
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  /// Rail takes the smaller golden-ratio slice of the detail column
  /// (width / φ² ≈ 38.2%), floored so narrow columns stay usable.
  private var railWidth: CGFloat {
    max(availableWidth * 0.382, 340)
  }

  /// Cover stays narrower than the rail instead of filling it edge to edge.
  private let coverWidth: CGFloat = 240

  /// Action card caps its width inside the rail, like the cover.
  private var cardWidth: CGFloat {
    min(400, railWidth)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 28) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          DetailCoverView(
            id: collection.id,
            type: .collection,
            width: coverWidth,
            cornerRadius: 12
          )
          .frame(maxWidth: .infinity, alignment: .center)

          CollectionHeroInfoView(collection: collection)
            .environment(\.detailHeroCentered, true)

          DetailActionCard {
            CollectionBookCountView(collection: collection)
          }
          .environment(\.detailHeroCentered, true)
          .frame(width: cardWidth)
          .frame(maxWidth: .infinity, alignment: .center)

          DetailTimestampsView(
            created: collection.createdDate, lastModified: collection.lastModifiedDate
          )
          .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical)
      }
      .scrollIndicators(.hidden)
      .frame(width: railWidth)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if item != nil {
            CollectionSeriesListView(
              collectionId: collectionId,
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.horizontal, 24)
  }
}
