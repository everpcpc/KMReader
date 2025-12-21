//
//  BrowseStateView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// Generic state view for browse screens
struct BrowseStateView<Content: View>: View {
  let isLoading: Bool
  let isEmpty: Bool
  let emptyIcon: String
  let emptyTitle: LocalizedStringKey
  let emptyMessage: LocalizedStringKey
  let onRetry: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    Group {
      if isLoading && isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else if isEmpty {
        VStack(spacing: 16) {
          Image(systemName: emptyIcon)
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text(emptyTitle)
            .font(.headline)
          Text(emptyMessage)
            .font(.subheadline)
            .foregroundColor(.secondary)
          Button(String(localized: "Retry")) {
            onRetry()
          }
        }
        .frame(maxWidth: .infinity)
        .padding()
      } else {
        content()

        if isLoading {
          ProgressView()
            .padding()
        }
      }
    }
  }
}
