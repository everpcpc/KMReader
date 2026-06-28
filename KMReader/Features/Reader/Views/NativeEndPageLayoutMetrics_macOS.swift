#if os(macOS)
  import AppKit

  @MainActor
  struct NativeEndPageLayoutMetrics {
    let outerPadding: CGFloat
    let stackSpacing: CGFloat
    let portraitSectionSpacing: CGFloat
    let horizontalDividerWidth: CGFloat
    let coverWidth: CGFloat
    let coverHeight: CGFloat
    let dividerHeight: CGFloat
    let badgeFont: NSFont
    let titleFont: NSFont
    let detailFont: NSFont

    static func resolve(for bounds: CGRect) -> NativeEndPageLayoutMetrics {
      let isPortrait = bounds.height >= bounds.width
      let minDimension = min(bounds.width, bounds.height)
      let maxDimension = max(bounds.width, bounds.height)
      let outerPadding = clamped(minDimension * 0.08, lower: 20, upper: 56)
      let stackSpacing = clamped(minDimension * 0.034, lower: 12, upper: 22)
      let coverWidth = clamped(
        minDimension * (isPortrait ? 0.28 : 0.22),
        lower: 96,
        upper: 190
      )

      return NativeEndPageLayoutMetrics(
        outerPadding: outerPadding,
        stackSpacing: stackSpacing,
        portraitSectionSpacing: stackSpacing + clamped(stackSpacing * 0.5, lower: 6, upper: 12),
        horizontalDividerWidth: clamped(bounds.width * 0.78, lower: 260, upper: 680),
        coverWidth: coverWidth,
        coverHeight: coverWidth / CoverAspectRatio.widthToHeight,
        dividerHeight: clamped(maxDimension * 0.32, lower: 140, upper: 320),
        badgeFont: .preferredFont(forTextStyle: .caption1),
        titleFont: .preferredFont(forTextStyle: .title3),
        detailFont: .preferredFont(forTextStyle: .caption1)
      )
    }

    private static func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
      Swift.min(Swift.max(value, lower), upper)
    }
  }
#endif
