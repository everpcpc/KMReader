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
  let width: CGFloat
  let cornerRadius: CGFloat
  let refreshTrigger: Int
  let alignment: Alignment
  let overlay: (() -> Overlay)?

  let ratio: CGFloat = 1.413

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @State private var localURL: URL?
  @State private var isLoading = true

  init(
    id: String?,
    type: ThumbnailType = .book,
    showPlaceholder: Bool = true,
    width: CGFloat,
    cornerRadius: CGFloat = 4,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.id = id
    self.type = type
    self.showPlaceholder = showPlaceholder
    self.width = width
    self.cornerRadius = cornerRadius
    self.refreshTrigger = refreshTrigger
    self.alignment = alignment
    self.overlay = overlay
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
          if thumbnailPreserveAspectRatio, let overlay = overlay {
            overlay()
              .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
          } else {
            EmptyView()
          }
        }
        .frame(width: width, height: width * ratio, alignment: alignment)
      } else {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.gray.opacity(0.3))
          .frame(width: width, height: width * ratio, alignment: alignment)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
          .overlay {
            if showPlaceholder && isLoading {
              ProgressView()
            }
          }
      }
    }
    .frame(width: width, height: width * ratio)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .overlay {
      if !thumbnailPreserveAspectRatio, let overlay = overlay {
        overlay()
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      } else {
        EmptyView()
      }
    }
    .shadow(color: Color.black.opacity(0.5), radius: 2)
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
    width: CGFloat,
    cornerRadius: CGFloat = 8,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center
  ) {
    self.init(
      id: id, type: type, showPlaceholder: showPlaceholder,
      width: width, cornerRadius: cornerRadius, refreshTrigger: refreshTrigger,
      alignment: alignment
    ) {}
  }
}
