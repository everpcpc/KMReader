//
//  EllipsisMenuButton.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct EllipsisMenuButton<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    Image(systemName: "ellipsis")
      .hidden()
      .overlay(
        Menu {
          content()
        } label: {
          Image(systemName: "ellipsis")
            .foregroundColor(.secondary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .appMenuStyle()
        .adaptiveButtonStyle(.plain)
      )
  }
}
