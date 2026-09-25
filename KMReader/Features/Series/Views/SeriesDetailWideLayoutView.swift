//
// SeriesDetailWideLayoutView.swift
//
//

import SwiftUI

/// Wide series detail (iPad regular width, macOS wide windows): the left
/// rail carries identity and about-info (cover, hero info, action card,
/// summary, metadata detail, timestamps); collections and the books list
/// flow in the right column. Rail and content scroll independently so the
/// rail never scrolls away with the books list.
struct SeriesDetailWideLayoutView<Actions: View>: View {
  let series: Series
  let item: SeriesDisplayItem?
  let collections: [SidebarCollectionItem]
  let seriesId: String
  let availableWidth: CGFloat
  @Bindable var bookViewModel: BookViewModel
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool
  @ViewBuilder let actions: Actions

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

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

  init(
    series: Series,
    item: SeriesDisplayItem?,
    collections: [SidebarCollectionItem],
    seriesId: String,
    availableWidth: CGFloat,
    bookViewModel: BookViewModel,
    showFilterSheet: Binding<Bool>,
    showSavedFilters: Binding<Bool>,
    @ViewBuilder actions: () -> Actions
  ) {
    self.series = series
    self.item = item
    self.collections = collections
    self.seriesId = seriesId
    self.availableWidth = availableWidth
    self.bookViewModel = bookViewModel
    self._showFilterSheet = showFilterSheet
    self._showSavedFilters = showSavedFilters
    self.actions = actions()
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && series.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    HStack(alignment: .top, spacing: 28) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          DetailCoverView(
            id: series.id,
            type: .series,
            contentBlurRadius: coverBlurRadius,
            width: coverWidth,
            cornerRadius: 12
          )
          .frame(maxWidth: .infinity, alignment: .center)

          SeriesHeroInfoView(series: series)
            .environment(\.detailHeroCentered, true)

          DetailActionCard {
            SeriesBookCountView(series: series)
            actions
          }
          .environment(\.detailHeroCentered, true)
          .frame(width: cardWidth)
          .frame(maxWidth: .infinity, alignment: .center)

          DetailTimestampsView(created: series.created, lastModified: series.lastModified)
            .frame(maxWidth: .infinity, alignment: .center)

          VStack(alignment: .leading, spacing: 16) {
            SeriesSummaryView(series: series)
            SeriesDetailChipsView(series: series)
            SeriesAlternateTitlesView(series: series)
          }
        }
        .padding(.vertical)
      }
      .scrollIndicators(.hidden)
      .frame(width: railWidth)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if item != nil {
            SeriesCollectionsSection(collections: collections)
              .padding(.horizontal)

            BooksListViewForSeries(
              seriesId: seriesId,
              bookViewModel: bookViewModel,
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
