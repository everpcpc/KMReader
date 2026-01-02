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
  let alignment: Alignment
  let overlay: (() -> Overlay)?

  let ratio: CGFloat = 1.414

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @Environment(\.zoomNamespace) private var zoomNamespace
  @State private var image: PlatformImage?
  @State private var currentBaseKey: String?

  private var effectiveShadowStyle: ShadowStyle {
    thumbnailShowShadow ? shadowStyle : .none
  }

  @ViewBuilder
  private var borderOverlay: some View {
    if !thumbnailShowShadow {
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
    }
  }

  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat? = nil,
    cornerRadius: CGFloat = 8,
    alignment: Alignment = .center,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.id = id
    self.type = type
    self.shadowStyle = shadowStyle
    self.width = width
    self.cornerRadius = cornerRadius
    self.alignment = alignment
    self.overlay = overlay
  }

  private var baseKey: String {
    "\(id)#\(type.rawValue)"
  }

  private func loadThumbnail(id: String, type: ThumbnailType) async -> PlatformImage? {
    await Task.detached(priority: .userInitiated) {
      let fileURL = ThumbnailCache.getThumbnailFileURL(id: id, type: type)
      let targetURL: URL?
      if FileManager.default.fileExists(atPath: fileURL.path) {
        targetURL = fileURL
      } else {
        targetURL = try? await ThumbnailCache.shared.ensureThumbnail(id: id, type: type)
      }

      guard !Task.isCancelled, let url = targetURL else { return nil }
      return PlatformImage(contentsOfFile: url.path)
    }.value
  }

  var body: some View {
    ZStack(alignment: alignment) {
      Color.clear

      Group {
        if let platformImage = image {
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
              .ifLet(zoomNamespace) { view, namespace in
                view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
              }
              #if os(iOS)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
              #endif
              .overlay { borderOverlay }

              .shadowStyle(effectiveShadowStyle, cornerRadius: cornerRadius)
          } else {
            GeometryReader { proxy in
              Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .ifLet(zoomNamespace) { view, namespace in
              view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
            }
            #if os(iOS)
              .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
            #endif
            .overlay { borderOverlay }
            .shadowStyle(effectiveShadowStyle, cornerRadius: cornerRadius)
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
    .task(id: baseKey) {
      if currentBaseKey != baseKey {
        currentBaseKey = baseKey
        image = nil
      }

      let loaded = await loadThumbnail(id: id, type: type)
      guard !Task.isCancelled, currentBaseKey == baseKey else { return }
      image = loaded
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
    alignment: Alignment = .center
  ) {
    self.init(
      id: id, type: type, shadowStyle: shadowStyle,
      width: width, cornerRadius: cornerRadius,
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
      alignment: .bottom
    )
    .frame(width: 200)
  }
}
