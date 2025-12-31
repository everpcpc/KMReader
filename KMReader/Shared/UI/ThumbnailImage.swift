//
//  ThumbnailImage.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// A reusable thumbnail image component using native image loading
struct ThumbnailImage<Overlay: View>: View {
  let id: String
  let type: ThumbnailType
  let shadowStyle: ShadowStyle
  let width: CGFloat
  let cornerRadius: CGFloat
  let refreshTrigger: Int
  let alignment: Alignment
  let overlay: (() -> Overlay)?

  let ratio: CGFloat = 1.414

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @Environment(\.readerZoomNamespace) private var zoomNamespace
  @State private var loadedImage: PlatformImage?

  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat,
    cornerRadius: CGFloat = 8,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.id = id
    self.type = type
    self.shadowStyle = shadowStyle
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
    Group {
      if let platformImage = loadedImage {
        Image(platformImage: platformImage)
          .resizable()
          .aspectRatio(contentMode: contentMode)
          .overlay {
            if thumbnailPreserveAspectRatio, let overlay = overlay {
              overlay()
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
          #if os(iOS)
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
          #endif
          .ifLet(zoomNamespace) { view, namespace in
            view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
          }
      } else {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.gray.opacity(0.3))
      }
    }
    .frame(width: width, height: width * ratio, alignment: alignment)
    .overlay {
      if !thumbnailPreserveAspectRatio, let overlay = overlay {
        overlay()
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .shadowStyle(shadowStyle)
    .task(id: "\(id)_\(refreshTrigger)") {
      let fileURL = ThumbnailCache.getThumbnailFileURL(id: id, type: type)

      var targetURL: URL?
      if FileManager.default.fileExists(atPath: fileURL.path) && refreshTrigger == 0 {
        targetURL = fileURL
      } else {
        targetURL = try? await ThumbnailCache.shared.ensureThumbnail(
          id: id, type: type, force: refreshTrigger > 0)
      }

      if let url = targetURL {
        loadedImage = PlatformImage(contentsOfFile: url.path)
      }
    }
  }
}

extension ThumbnailImage where Overlay == EmptyView {
  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat,
    cornerRadius: CGFloat = 8,
    refreshTrigger: Int = 0,
    alignment: Alignment = .center
  ) {
    self.init(
      id: id, type: type, shadowStyle: shadowStyle,
      width: width, cornerRadius: cornerRadius, refreshTrigger: refreshTrigger,
      alignment: alignment
    ) {}
  }
}

#Preview {
  VStack {
    ThumbnailImage(
      id: "1",
      type: .book,
      shadowStyle: .platform,
      width: 200,
      cornerRadius: 8,
      refreshTrigger: 0,
      alignment: .center
    )
  }
}
