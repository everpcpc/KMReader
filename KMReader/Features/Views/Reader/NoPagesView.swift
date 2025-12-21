//
//  NoPagesView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct NoPagesView: View {
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 64))
        .foregroundColor(.white.opacity(0.7))

      VStack(spacing: 12) {
        Text("No Pages Available")
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundColor(.white)

        Text(
          "Unable to load pages for this book. This format may not be supported."
        )
        .font(.body)
        .foregroundColor(.white.opacity(0.8))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
      }

      Button {
        onDismiss()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .semibold))
          Text("Close")
            .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 25)
            .fill(Color.white.opacity(0.2))
            .overlay(
              RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
