//
//  KMReaderWidgetsBundle.swift
//  KMReaderWidgets
//
//  Created by Chuan Chuan on 2025/12/23.
//

import SwiftUI
import WidgetKit

#if os(iOS)
  @main
  struct KMReaderWidgetsBundle: WidgetBundle {
    var body: some Widget {
      KMReaderWidgetsLiveActivity()
    }
  }
#endif
