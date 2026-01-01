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
  let width: CGFloat?
  let cornerRadius: CGFloat
  let refreshTrigger: Int
  let alignment: Alignment
  let overlay: (() -> Overlay)?

  let ratio: CGFloat = 1.414

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @Environment(\.zoomNamespace) private var zoomNamespace
  @State private var loadedImage: PlatformImage?

  private var effectiveShadowStyle: ShadowStyle {
    thumbnailShowShadow ? shadowStyle : .none
  }

  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat? = nil,
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

  var body: some View {
    ZStack(alignment: alignment) {
      Color.clear

      Group {
        if let platformImage = loadedImage {
          if thumbnailPreserveAspectRatio {
            Image(platformImage: platformImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .overlay {
                if let overlay = overlay {
                  overlay()
                }
              }
              .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
              #if os(iOS)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
              #endif
              .shadowStyle(effectiveShadowStyle, cornerRadius: cornerRadius)
              .ifLet(zoomNamespace) { view, namespace in
                view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
              }
          } else {
            GeometryReader { proxy in
              Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            #if os(iOS)
              .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
            #endif
            .shadowStyle(effectiveShadowStyle, cornerRadius: cornerRadius)
            .ifLet(zoomNamespace) { view, namespace in
              view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
            }
          }
        } else {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.3))
        }
      }
      .overlay {
        if !thumbnailPreserveAspectRatio, let overlay = overlay {
          overlay()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
      }
    }
    .aspectRatio(1 / ratio, contentMode: .fit)
    .frame(width: width)
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
    width: CGFloat? = nil,
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
      cornerRadius: 8,
      refreshTrigger: 0,
      alignment: .bottom
    )
    .frame(width: 200)
  }
}
