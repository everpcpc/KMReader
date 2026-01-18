//
//  LoadingIcon.swift
//  KMReader
//

import SwiftUI

struct LoadingIcon: View {
  var body: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .tint(.secondary)
    // if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
    //   Image(systemName: "arrow.clockwise.circle")
    //     .symbolEffect(.rotate.byLayer, options: .repeat(.periodic(delay: 0.0)))
    //     .foregroundStyle(.secondary)
    // } else {
    //   Image(systemName: "arrow.clockwise.circle")
    //     .animation(.easeInOut(duration: 1).repeatForever(), value: 0)
    //     .foregroundStyle(.secondary)
    // }
  }
}
