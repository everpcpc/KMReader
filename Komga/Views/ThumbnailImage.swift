//
//  ThumbnailImage.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SDWebImage
import SDWebImageSwiftUI
import SwiftUI

/// A reusable thumbnail image component using SDWebImageSwiftUI
struct ThumbnailImage: View {
  let url: URL?
  let showPlaceholder: Bool
  let width: CGFloat
  let cornerRadius: CGFloat
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true

  init(
    url: URL?,
    showPlaceholder: Bool = true,
    width: CGFloat,
    cornerRadius: CGFloat = 8
  ) {
    self.url = url
    self.showPlaceholder = showPlaceholder
    self.width = width
    self.cornerRadius = cornerRadius
  }

  private var contentMode: ContentMode {
    if thumbnailPreserveAspectRatio {
      return .fit
    } else {
      return .fill
    }
  }

  var body: some View {
    ZStack {
      // Background container with rounded corners
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(Color.clear)
        .frame(width: width, height: width * 1.3)

      // Image content
      if let url = url {
        WebImage(
          url: url,
          options: [.retryFailed, .scaleDownLargeImages],
          context: [.customManager: SDImageCacheProvider.thumbnailManager]
        )
        .resizable()
        .placeholder {
          if showPlaceholder {
            Rectangle()
              .fill(Color.gray.opacity(0.3))
              .overlay {
                ProgressView()
              }
          } else {
            Rectangle()
              .fill(Color.gray.opacity(0.3))
          }
        }
        .indicator(.activity)
        .transition(.fade(duration: 0.2))
        .aspectRatio(contentMode: contentMode)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .frame(width: width, height: width * 1.3, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      } else {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.gray.opacity(0.3))
          .frame(width: width, height: width * 1.3, alignment: .center)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
          .overlay {
            if showPlaceholder {
              ProgressView()
            }
          }
      }

    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .shadow(color: Color.black.opacity(0.5), radius: 4)
  }
}
