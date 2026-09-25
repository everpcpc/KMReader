//
// SeriesDetailContentView.swift
//
//

import SwiftUI

struct SeriesDetailContentView<Actions: View>: View {
  let series: Series
  /// iPad's narrow single-column fallback forces the compact centered hero
  /// and caps the action card instead of stretching both across the column.
  let forceCompactHero: Bool
  @ViewBuilder let actions: Actions

  @AppStorage("thumbnailBlurUnreadCovers") private var thumbnailBlurUnreadCovers: Bool = false

  init(series: Series, forceCompactHero: Bool = false, @ViewBuilder actions: () -> Actions) {
    self.series = series
    self.forceCompactHero = forceCompactHero
    self.actions = actions()
  }

  private var coverBlurRadius: CGFloat {
    thumbnailBlurUnreadCovers && series.isUnread ? CoverBlurStyle.unreadRadius : 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeroView(
        id: series.id,
        type: .series,
        contentBlurRadius: coverBlurRadius,
        forceCentered: forceCompactHero
      ) {
        SeriesHeroInfoView(series: series)
      }

      DetailActionCard {
        SeriesBookCountView(series: series)

        actions
      }
      .environment(\.detailHeroCentered, forceCompactHero)
      .frame(maxWidth: forceCompactHero ? 480 : .infinity)
      .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)

      DetailTimestampsView(created: series.created, lastModified: series.lastModified)
        .frame(maxWidth: .infinity, alignment: forceCompactHero ? .center : .leading)

      SeriesSummaryView(series: series)

      SeriesDetailChipsView(series: series)

      SeriesAlternateTitlesView(series: series)
    }
  }
}
