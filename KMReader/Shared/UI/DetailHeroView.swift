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
/// side-by-side row at `PlatformHelper.detailThumbnailWidth`. The centered
/// branch injects `detailHeroCentered` so only hero subviews adapt alignment.
struct DetailHeroView<Info: View>: View {
  let id: String
  let type: ThumbnailType
  let contentBlurRadius: CGFloat
  let forceCentered: Bool
  @ViewBuilder let info: Info

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  init(
    id: String,
    type: ThumbnailType,
    contentBlurRadius: CGFloat,
    forceCentered: Bool = false,
    @ViewBuilder info: () -> Info
  ) {
    self.id = id
    self.type = type
    self.contentBlurRadius = contentBlurRadius
    self.forceCentered = forceCentered
    self.info = info()
  }

  private var isCentered: Bool {
    forceCentered || horizontalSizeClass == .compact
  }

  var body: some View {
    if isCentered {
      VStack(spacing: 16) {
        DetailCoverView(id: id, type: type, contentBlurRadius: contentBlurRadius, width: 180)
        info
          .frame(maxWidth: .infinity)
      }
      .environment(\.detailHeroCentered, true)
    } else {
      HStack(alignment: .top, spacing: 12) {
        DetailCoverView(
          id: id,
          type: type,
          contentBlurRadius: contentBlurRadius,
          width: PlatformHelper.detailThumbnailWidth
        )
        info
      }
    }
  }
}
