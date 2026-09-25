//
// CoverTintedCardBackground.swift
//
//

import SwiftUI

/// Rounded card background tinted by a book cover (Apple Books style): the
/// cover is stretched, heavily blurred, and dimmed behind the card, with the
/// plain material as the fallback until the cover loads. Content on top should
/// switch to light colors while `artwork` is set. Load `artwork` with
/// `coverArtwork(instanceId:bookId:into:)`.
struct CoverTintedCardBackground: View {
  let artwork: PlatformImage?

  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.regularMaterial)
      .overlay {
        // Overlay content never contributes to layout size, so the flexible
        // blurred image can neither inflate the card nor bleed past it.
        if let artwork {
          // No scaledToFill: stretch the whole cover into the card so the
          // tint mixes the cover's overall tone instead of only the cropped
          // middle strip. The heavy blur hides the distortion.
          Image(platformImage: artwork)
            .resizable()
            // Overscan before blurring: the blur samples transparent black
            // beyond the image bounds, which darkened the card edges.
            .scaleEffect(1.3)
            .compositingGroup()
            .blur(radius: 28)
            .saturation(0.7)
            // Even dimming layer: tinted cards force white text, so light
            // covers still need enough overlay for the title to stay readable.
            .overlay(Color.black.opacity(0.4))
            .transition(.opacity)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
      .animation(.easeInOut(duration: 0.2), value: artwork != nil)
  }
}
