//
//  KMReaderWidgetsBundle.swift
//  KMReaderWidgets
//
//  Created by Chuan Chuan on 2025/12/23.
//

import SwiftUI
import WidgetKit

@main
struct KMReaderWidgetsBundle: WidgetBundle {
  var body: some Widget {
    #if os(iOS)
      KMReaderWidgetsLiveActivity()
      KMReaderReaderLiveActivity()
    #endif
    KeepReadingWidget()
    RecentlyAddedWidget()
    RecentlyUpdatedSeriesWidget()
  }
}
