//
//  ThumbnailImage.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

/// A reusable thumbnail image component using native image loading
struct ThumbnailImage<Overlay: View, Menu: View>: View {
  let id: String
  let type: ThumbnailType
  let shadowStyle: ShadowStyle
  let width: CGFloat?
  let cornerRadius: CGFloat
  let alignment: Alignment
  let isTransitionSource: Bool
  let navigationLink: NavDestination?
  let onAction: (() -> Void)?
  let overlay: (() -> Overlay)?
  let menu: (() -> Menu)?

  let ratio: CGFloat = 1.414

  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @Environment(\.zoomNamespace) private var zoomNamespace

  @State private var isLoading: Bool = true
  @State private var image: PlatformImage?
  @State private var currentBaseKey: String?
  @State private var loadedImageSize: CGSize?
  @State private var refreshTrigger: UUID = UUID()

  private var effectiveShadowStyle: ShadowStyle {
    return thumbnailShowShadow ? shadowStyle : .none
  }

  private var shouldShowPlaceholder: Bool {
    !isLoading && image == nil
  }

  @ViewBuilder
  private var borderOverlay: some View {
    if !thumbnailShowShadow {
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
    }
  }

  @ViewBuilder
  private func thumbnailBase<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .overlay { borderOverlay }
      .ifLet(isTransitionSource ? zoomNamespace : nil) { view, namespace in
        view.matchedTransitionSourceIfAvailable(id: id, in: namespace)
      }
      #if os(iOS)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
      #endif
      .withNavigationLink(navigationLink, cornerRadius: cornerRadius)
      .withButtonAction(onAction, cornerRadius: cornerRadius)
      .contextMenu {
        if let menu = menu {
          menu()
        }
      }
      .overlay {
        if !isAbnormalSize, let overlay = overlay {
          overlay()
        }
      }
      .transition(.opacity)
  }

  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat? = nil,
    cornerRadius: CGFloat = 8,
    alignment: Alignment = .center,
    isTransitionSource: Bool = true,
    navigationLink: NavDestination? = nil,
    onAction: (() -> Void)? = nil,
    @ViewBuilder overlay: @escaping () -> Overlay,
    @ViewBuilder menu: @escaping () -> Menu,
  ) {
    self.id = id
    self.type = type
    self.shadowStyle = shadowStyle
    self.width = width
    self.cornerRadius = cornerRadius
    self.alignment = alignment
    self.isTransitionSource = isTransitionSource
    self.navigationLink = navigationLink
    self.onAction = onAction
    self.overlay = overlay
    self.menu = menu
  }

  private var baseKey: String {
    "\(id)#\(type.rawValue)"
  }

  private var isAbnormalSize: Bool {
    guard let loadedImageSize = loadedImageSize else { return false }
    guard thumbnailPreserveAspectRatio else { return false }
    let realRatio = loadedImageSize.height / loadedImageSize.width
    return realRatio < 0.35 || realRatio > 2.828
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
      guard let image = PlatformImage(contentsOfFile: url.path) else { return nil }
      return await ImageDecodeHelper.decodeForDisplay(image)
    }.value
  }

  var body: some View {
    ZStack(alignment: alignment) {
      Color.clear

      if image != nil {
        thumbnailBase {
          imageContent
        }
        .shadowStyle(effectiveShadowStyle, cornerRadius: cornerRadius)
      } else if shouldShowPlaceholder {
        thumbnailBase {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.secondary)
        }
      }
    }
    .animation(.easeInOut(duration: 0.18), value: refreshTrigger)
    .aspectRatio(1 / ratio, contentMode: .fit)
    .frame(width: width)
    .overlay {
      if isAbnormalSize, let overlay = overlay {
        overlay()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidRefresh)) { notification in
      guard let userInfo = notification.userInfo,
        let notificationId = userInfo["id"] as? String,
        let notificationType = userInfo["type"] as? String,
        notificationId == id,
        notificationType == type.rawValue
      else {
        return
      }
      refreshTrigger = UUID()
    }
    .task(id: refreshTrigger) {
      isLoading = true
      if currentBaseKey != baseKey {
        currentBaseKey = baseKey
        image = nil
      }

      let loaded = await loadThumbnail(id: id, type: type)
      guard !Task.isCancelled, currentBaseKey == baseKey else { return }
      if let loaded = loaded {
        loadedImageSize = loaded.size
        image = loaded
      }
      isLoading = false
    }
  }

  @ViewBuilder
  var imageContent: some View {
    if let platformImage = image {
      if thumbnailPreserveAspectRatio {
        Image(platformImage: platformImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        GeometryReader { proxy in
          Image(platformImage: platformImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
      }
    }
  }
}

extension ThumbnailImage where Overlay == EmptyView, Menu == EmptyView {
  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat? = nil,
    cornerRadius: CGFloat = 8,
    alignment: Alignment = .center,
    isTransitionSource: Bool = true,
    navigationLink: NavDestination? = nil,
    onAction: (() -> Void)? = nil,
  ) {
    self.init(
      id: id, type: type, shadowStyle: shadowStyle,
      width: width, cornerRadius: cornerRadius,
      alignment: alignment,
      isTransitionSource: isTransitionSource,
      navigationLink: navigationLink,
      onAction: onAction
    ) {
    } menu: {
    }
  }
}

extension ThumbnailImage where Menu == EmptyView {
  init(
    id: String,
    type: ThumbnailType = .book,
    shadowStyle: ShadowStyle = .basic,
    width: CGFloat? = nil,
    cornerRadius: CGFloat = 8,
    alignment: Alignment = .center,
    isTransitionSource: Bool = true,
    navigationLink: NavDestination? = nil,
    onAction: (() -> Void)? = nil,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.init(
      id: id, type: type, shadowStyle: shadowStyle,
      width: width, cornerRadius: cornerRadius,
      alignment: alignment,
      isTransitionSource: isTransitionSource,
      navigationLink: navigationLink,
      onAction: onAction
    ) {
      overlay()
    } menu: {
    }
  }
}

extension View {
  @ViewBuilder
  func withButtonAction(_ onAction: (() -> Void)?, cornerRadius: CGFloat = 8) -> some View {
    if let onAction = onAction {
      Button(action: onAction) {
        self
      }
      .adaptiveButtonStyle(.plain)
    } else {
      self
    }
  }

  @ViewBuilder
  func withNavigationLink(_ navigationLink: NavDestination?, cornerRadius: CGFloat = 8) -> some View {
    if let navigationLink = navigationLink {
      NavigationLink(value: navigationLink) {
        self
      }
      .adaptiveButtonStyle(.plain)
    } else {
      self
    }
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
