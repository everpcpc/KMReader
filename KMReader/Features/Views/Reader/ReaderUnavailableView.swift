//
//  ReaderUnavailableView.swift
//  KMReader
//

import SwiftUI

struct ReaderUnavailableView: View {
  let icon: String
  let title: LocalizedStringKey
  let message: String?
  let onClose: () -> Void

  #if os(tvOS)
    @FocusState private var isCloseButtonFocused: Bool
  #endif

  init(
    icon: String,
    title: LocalizedStringKey,
    message: String? = nil,
    onClose: @escaping () -> Void
  ) {
    self.icon = icon
    self.title = title
    self.message = message
    self.onClose = onClose
  }

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: icon)
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
        if let message, !message.isEmpty {
          Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }

      Button {
        onClose()
      } label: {
        Label("Close", systemImage: "xmark.circle.fill")
          .font(.headline)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
      }
      .adaptiveButtonStyle(.borderedProminent)
      #if os(tvOS)
        .focused($isCloseButtonFocused)
      #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
    // #if os(tvOS)
    //   .onAppear {
    //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    //       isCloseButtonFocused = true
    //     }
    //   }
    // #endif
  }
}
