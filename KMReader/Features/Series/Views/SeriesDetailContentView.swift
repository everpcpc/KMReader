//
// SeriesDetailContentView.swift
//
//

import SwiftUI

struct SeriesDetailContentView<Actions: View>: View {
  let series: Series
  @ViewBuilder let actions: Actions

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  init(series: Series, @ViewBuilder actions: () -> Actions) {
    self.series = series
    self.actions = actions()
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && series.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  private var isCompactLayout: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: series.id,
        type: .series,
        contentBlurRadius: coverBlurRadius
      ) {
        SeriesHeroInfoView(series: series)
      }

      DetailActionCard {
        SeriesBookCountView(series: series)

        actions
      }
      .frame(maxWidth: isCompactLayout ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)

      DetailTimestampsView(created: series.created, lastModified: series.lastModified)
        .frame(maxWidth: .infinity, alignment: isCompactLayout ? .center : .leading)

      SeriesSummaryView(series: series)

      SeriesDetailChipsView(series: series)

      SeriesAlternateTitlesView(series: series)
    }
    .environment(\.detailHeroCentered, isCompactLayout)
  }
}
