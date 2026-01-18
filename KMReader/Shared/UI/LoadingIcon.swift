//
//  LoadingIcon.swift
//  KMReader
//

import SwiftUI

struct LargeLoadingIcon: View {
  @State private var isRotating = 0.0

  var body: some View {
    Image(systemName: "arrow.clockwise")
      .font(.system(size: 24, weight: .semibold))
      .foregroundStyle(
        LinearGradient(
          colors: [.accentColor, .accentColor.opacity(0.5)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .rotationEffect(.degrees(isRotating))
      .onAppear {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
          isRotating = 360.0
        }
      }
  }
}

struct LoadingIcon: View {

  var body: some View {
    ProgressView()
      .progressViewStyle(.circular)
  }
}
