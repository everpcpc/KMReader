//
// DetailHeroView.swift
//
//

import SwiftUI

private struct DetailHeroCenteredKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Set by detail pages so hero subviews (title, author chips, metadata
  /// rows) can switch to centered alignment under the stacked compact hero.
  var detailHeroCentered: Bool {
    get { self[DetailHeroCenteredKey.self] }
    set { self[DetailHeroCenteredKey.self] = newValue }
  }
}

/// Detail page hero: cover plus an info block. Compact widths (iPhone) stack
/// a large cover above the centered info block; regular widths keep the
/// side-by-side row at `PlatformHelper.detailThumbnailWidth`.
struct DetailHeroView<Info: View>: View {
  let id: String
  let type: ThumbnailType
  let contentBlurRadius: CGFloat
  @ViewBuilder let info: Info

  @Environment(\.detailHeroCentered) private var isCentered

  @State private var thumbnailRefreshKey = UUID()

  var body: some View {
    if isCentered {
      VStack(spacing: 16) {
        cover(width: 180)
        info
          .frame(maxWidth: .infinity)
      }
    } else {
      HStack(alignment: .top, spacing: 12) {
        cover(width: PlatformHelper.detailThumbnailWidth)
        info
      }
    }
  }

  private func cover(width: CGFloat) -> some View {
    ThumbnailImage(
      id: id,
      type: type,
      contentBlurRadius: contentBlurRadius,
      width: width,
      isTransitionSource: false,
      onAction: {}
    ) {
    } menu: {
      Button {
        Task {
          do {
            _ = try await ThumbnailCache.shared.ensureThumbnail(
              id: id,
              type: type,
              force: true
            )
            thumbnailRefreshKey = UUID()
            ErrorManager.shared.notify(
              message: String(localized: "notification.cover.refreshed"))
          } catch {
            ErrorManager.shared.notify(
              message: String(localized: "notification.cover.refreshFailed"))
          }
        }
      } label: {
        Label(String(localized: "Refresh Cover"), systemImage: "arrow.clockwise")
      }
    }
    .id(thumbnailRefreshKey)
  }
}
