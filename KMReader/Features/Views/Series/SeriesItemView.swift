//
//  SeriesItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesItemView: View {
  @Bindable var series: KomgaSeries
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  var onActionCompleted: (() -> Void)? = nil

  var body: some View {
    switch layout {
    case .grid:
      SeriesCardView(
        komgaSeries: series,
        cardWidth: cardWidth,
        onActionCompleted: onActionCompleted
      )
    case .list:
      SeriesRowView(
        komgaSeries: series,
        onActionCompleted: onActionCompleted
      )
    }
  }
}
