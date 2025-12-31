//
//  KeyboardHelpOverlay.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(macOS)
  import AppKit

  // Keyboard shortcuts help overlay
  struct KeyboardHelpOverlay: View {
    let readingDirection: ReadingDirection
    let hasTOC: Bool
    let hasNextBook: Bool
    let onDismiss: () -> Void

    var body: some View {
      ZStack {
        // Semi-transparent background
        Button {
          onDismiss()
        } label: {
          Color.black.opacity(0.5)
        }
        .adaptiveButtonStyle(.plain)

        // Help content
        VStack(spacing: 20) {
          Text("Keyboard Shortcuts")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)

          VStack(alignment: .leading, spacing: 12) {
            HelpRow(key: "ESC", description: "Close reader")
            HelpRow(key: "? / H", description: "Show this help")

            Divider()
              .background(Color.white.opacity(0.3))

            HelpRow(key: "F / Return", description: "Toggle fullscreen")
            HelpRow(key: "C / Space", description: "Toggle controls")
            if hasTOC {
              HelpRow(key: "T", description: "Table of Contents")
            }
            HelpRow(key: "J", description: "Jump to page")
            if hasNextBook {
              HelpRow(key: "N", description: "Next book")
            }

            Divider()
              .background(Color.white.opacity(0.3))

            // Navigation keys based on reading direction
            Group {
              switch readingDirection {
              case .ltr:
                HelpRow(key: "→", description: "Next page")
                HelpRow(key: "←", description: "Previous page")
              case .rtl:
                HelpRow(key: "←", description: "Next page")
                HelpRow(key: "→", description: "Previous page")
              case .vertical:
                HelpRow(key: "↓", description: "Next page")
                HelpRow(key: "↑", description: "Previous page")
              case .webtoon:
                HelpRow(key: "↓", description: "Scroll down")
                HelpRow(key: "↑", description: "Scroll up")
              }
            }
          }
          .padding()
          .background(Color.black.opacity(0.8))
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.3), lineWidth: 1)
          )

          Button {
            onDismiss()
          } label: {
            Text("Close")
              .foregroundColor(.white)
              .padding(.horizontal, 24)
              .padding(.vertical, 8)
              .background(Color.accentColor.opacity(0.9))
              .cornerRadius(8)
          }
          .adaptiveButtonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: 500)
      }
    }
  }

  private struct HelpRow: View {
    let key: String
    let description: String

    var body: some View {
      HStack {
        Text(key)
          .font(.system(.body, design: .monospaced))
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.white.opacity(0.2))
          .cornerRadius(6)
          .frame(width: 130, alignment: .leading)

        Text(description)
          .foregroundColor(.white.opacity(0.9))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
#endif
