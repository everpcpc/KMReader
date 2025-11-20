//
//  EndPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct EndPageView: View {
  let nextBook: Book?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let isRTL: Bool

  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 16) {

        // Next book button for RTL
        if isRTL, let nextBook = nextBook {
          Button {
            onNextBook(nextBook.id)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .semibold))
              Text("Next")
                .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 25)
                .fill(themeColorOption.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
          }
        }

        // Dismiss button
        Button {
          onDismiss()
        } label: {
          HStack(spacing: 8) {
            if !isRTL {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
            }
            Text("Close")
              .font(.system(size: 16, weight: .medium))
            if isRTL {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
            }
          }
          .foregroundColor(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 25)
              .fill(Color.black.opacity(0.85))
              .overlay(
                RoundedRectangle(cornerRadius: 25)
                  .stroke(Color.white.opacity(0.2), lineWidth: 1)
              )
          )
        }

        // Next book button
        if !isRTL, let nextBook = nextBook {
          Button {
            onNextBook(nextBook.id)
          } label: {
            HStack(spacing: 8) {
              Text("Next")
                .font(.system(size: 16, weight: .medium))
              Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 25)
                .fill(themeColorOption.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
          }
        }
      }
      NextBookInfoView(nextBook: nextBook)
    }
  }
}

struct NextBookInfoView: View {
  let nextBook: Book?

  var body: some View {
    if let nextBook = nextBook {
      VStack {
        Label("UP NEXT: #\(Int(nextBook.number))", systemImage: "arrow.right.circle")
        Text(nextBook.metadata.title)
      }
      .foregroundColor(.white.opacity(0.9))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.black.opacity(0.6))
      )
    } else {
      HStack(spacing: 8) {
        Image(systemName: "checkmark.circle")
          .font(.system(size: 14))
        Text("You're all caught up!")
          .font(.system(size: 14, weight: .medium))
      }
      .foregroundColor(.white.opacity(0.7))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.black.opacity(0.6))
      )
    }
  }
}
