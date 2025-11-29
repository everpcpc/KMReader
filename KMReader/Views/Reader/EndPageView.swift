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
  let goToPreviousPage: (() -> Void)?

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

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
                .fill(themeColor.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .buttonStyle(.plain)
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
          .foregroundColor(themeColor.color)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 25)
              .fill(Color.clear)
              .overlay(
                RoundedRectangle(cornerRadius: 25)
                  .stroke(themeColor.color.opacity(0.5), lineWidth: 1)
              )
          )
          .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)

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
                .fill(themeColor.color.opacity(0.85))
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
          }
          .buttonStyle(.plain)
        }
      }
      #if os(tvOS)
        .focusSection()
        .onMoveCommand { direction in
          // Handle going back to previous page
          switch direction {
          case .left where !isRTL, .right where isRTL, .up:
            goToPreviousPage?()
          default:
            break
          }
        }
      #endif
      NextBookInfoView(nextBook: nextBook)
    }
  }
}
