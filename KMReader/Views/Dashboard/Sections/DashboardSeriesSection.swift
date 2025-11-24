//
//  DashboardSeriesSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DashboardSeriesSection: View {
  let title: String
  let series: [Series]
  var seriesViewModel: SeriesViewModel
  var onSeriesUpdated: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(series) { s in
            NavigationLink(value: NavDestination.seriesDetail(seriesId: s.id)) {
              SeriesCardView(
                series: s,
                cardWidth: 120,
                onActionCompleted: onSeriesUpdated
              )
            }
            .buttonStyle(.plain)
          }
        }.padding()
      }
    }
  }
}
