//
//  SeriesItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesItemView: View {
  @Bindable var series: KomgaSeries
  let layout: BrowseLayoutMode

  var body: some View {
    switch layout {
    case .grid:
      SeriesCardView(
        komgaSeries: series
      )
    case .list:
      SeriesRowView(
        komgaSeries: series
      )
    }
  }
}
