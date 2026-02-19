//
//  ThumbnailOverlayGradient.swift
//  Komga
//
//

import SwiftUI

struct ThumbnailOverlayGradient: View {
  enum Position {
    case top
    case bottom
    case both
  }

  let position: Position

  init(position: Position = .both) {
    self.position = position
  }

  var body: some View {
    switch position {
    case .top:
      LinearGradient(
        stops: [
          .init(color: .black.opacity(0.5), location: 0),
          .init(color: .black.opacity(0.2), location: 0.2),
          .init(color: .black.opacity(0.0), location: 0.4),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .bottom:
      LinearGradient(
        stops: [
          .init(color: .black.opacity(0.0), location: 0.8),
          .init(color: .black.opacity(0.2), location: 0.9),
          .init(color: .black.opacity(0.5), location: 0.95),
          .init(color: .black.opacity(0.7), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .both:
      ZStack {
        LinearGradient(
          stops: [
            .init(color: .black.opacity(0.5), location: 0),
            .init(color: .black.opacity(0.2), location: 0.2),
            .init(color: .black.opacity(0.0), location: 0.4),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        LinearGradient(
          stops: [
            .init(color: .black.opacity(0.0), location: 0.8),
            .init(color: .black.opacity(0.2), location: 0.9),
            .init(color: .black.opacity(0.5), location: 0.95),
            .init(color: .black.opacity(0.7), location: 1.0),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
    }
  }
}
