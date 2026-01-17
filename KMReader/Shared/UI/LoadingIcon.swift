//
//  LoadingIcon.swift
//  KMReader
//

import SwiftUI

struct LoadingIcon: View {
  var body: some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
      Image(systemName: "arrow.clockwise")
        .symbolEffect(.rotate.byLayer, options: .repeat(.periodic(delay: 0.0)))
    } else {
      Image(systemName: "arrow.clockwise")
        .animation(.easeInOut(duration: 1).repeatForever(), value: 0)
    }
  }
}
