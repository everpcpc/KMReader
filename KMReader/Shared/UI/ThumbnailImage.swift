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
struct ThumbnailImage<Overlay: View>: View {
  let id: String?
  let type: ThumbnailType
  let showPlaceholder: Bool
  let shadowStyle: ShadowStyle
  let showSpine: Bool
  let width: CGFloat
  let cornerRadius: CGFloat
  let refreshTrigger: Int
  let alignment: Alignment
  let overlay: (() -> Overlay)?

  let ratio: CGFloat = 1.413

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @Environment(\.colorScheme) private var colorScheme
  @State private var localURL: URL?
  @State private var isLoading = true

  init(
    id: String?,
    type: ThumbnailType = .book,
    showPlaceholder: Bool = true,
    shadowStyle: ShadowStyle = .basic,
    showSpine: Bool = true,
    width: CGFloat,
    cornerRadius: CGFloat = 4,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.id = id
    self.type = type
    self.showPlaceholder = showPlaceholder
    self.shadowStyle = shadowStyle
    self.showSpine = showSpine
    self.width = width
    self.cornerRadius = cornerRadius
    self.refreshTrigger = refreshTrigger
    self.alignment = alignment
    self.overlay = overlay
  }

  private var effectiveCornerRadius: CGFloat {
    showSpine ? 2 : cornerRadius
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
      RoundedRectangle(cornerRadius: effectiveCornerRadius)
        .fill(Color.clear)
        .frame(width: width, height: width * ratio)

      // Image content - this will be the target for overlay alignment
      if let localURL = localURL {
        WebImage(
          url: localURL,
          options: [.retryFailed, .scaleDownLargeImages],
          context: [.customManager: SDImageCacheProvider.thumbnailManager]
        )
        .resizable()
        .placeholder {
          Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
              if showPlaceholder {
                ProgressView()
              }
            }
        }
        .indicator(.activity)
        .transition(.fade)
        .aspectRatio(contentMode: contentMode)
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
        .overlay {
          if thumbnailPreserveAspectRatio, let overlay = overlay {
            overlay()
            .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
          } else {
            EmptyView()
          }
        }
        .bookSpine(showSpine)
        .background {
          if shadowStyle == .platform {
            RoundedRectangle(cornerRadius: effectiveCornerRadius)
              .fill(colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.15))
              .offset(y: colorScheme == .light ? 12 : 6)
              .blur(radius: colorScheme == .light ? 12 : 12)
              .scaleEffect(x: 0.9)
          }
        }
        .shadow(
          color: shadowStyle == .platform ? (colorScheme == .light ? .black.opacity(0.15) : .white.opacity(0.1)) : .clear,
          radius: shadowStyle == .platform ? 2 : 0,
          x: 0,
          y: shadowStyle == .platform ? 1 : 0
        )
        .frame(width: width, height: width * ratio, alignment: alignment)
      } else {
        RoundedRectangle(cornerRadius: effectiveCornerRadius)
          .fill(Color.gray.opacity(0.3))
          .frame(width: width, height: width * ratio, alignment: alignment)
          .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
          .overlay {
            if showPlaceholder && isLoading {
              ProgressView()
            }
          }
      }
    }
    .frame(width: width, height: width * ratio)
    .overlay {
      if !thumbnailPreserveAspectRatio, let overlay = overlay {
        overlay()
          .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
      } else {
        EmptyView()
      }
    }
    .shadow(color: shadowStyle == .basic ? Color.black.opacity(0.5) : .clear, radius: shadowStyle == .basic ? 2 : 0)
    .task(id: "\(id ?? "")_\(refreshTrigger)") {
      guard let id = id else {
        isLoading = false
        return
      }

      if localURL == nil {
        isLoading = true
      }
      let fileURL = ThumbnailCache.getThumbnailFileURL(id: id, type: type)

      if FileManager.default.fileExists(atPath: fileURL.path) && refreshTrigger == 0 {
        localURL = fileURL
      } else {
        localURL = try? await ThumbnailCache.shared.ensureThumbnail(
          id: id, type: type, force: refreshTrigger > 0)
      }

      isLoading = false
    }
  }
}

extension ThumbnailImage where Overlay == EmptyView {
  init(
    id: String?,
    type: ThumbnailType = .book,
    showPlaceholder: Bool = true,
    shadowStyle: ShadowStyle = .basic,
    showSpine: Bool = true,
    width: CGFloat,
    cornerRadius: CGFloat = 8,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center
  ) {
    self.init(
      id: id, type: type, showPlaceholder: showPlaceholder, shadowStyle: shadowStyle,
      showSpine: showSpine,
      width: width, cornerRadius: cornerRadius, refreshTrigger: refreshTrigger,
      alignment: alignment
    ) {}
  }
}
