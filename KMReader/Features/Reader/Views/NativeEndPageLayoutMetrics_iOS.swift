#if os(iOS) || os(tvOS)
  import UIKit

  @MainActor
  struct NativeEndPageLayoutMetrics {
    let outerPadding: CGFloat
    let innerPadding: CGFloat
    let stackSpacing: CGFloat
    let portraitSectionSpacing: CGFloat
    let horizontalDividerWidth: CGFloat
    let coverWidth: CGFloat
    let coverHeight: CGFloat
    let dividerHeight: CGFloat
    let badgeFont: UIFont
    let titleFont: UIFont
    let detailFont: UIFont

    static func resolve(for bounds: CGRect) -> NativeEndPageLayoutMetrics {
      let minDimension = min(bounds.width, bounds.height)
      let maxDimension = max(bounds.width, bounds.height)
      let outerPadding = platformOuterPadding(minDimension: minDimension)
      let innerPadding = platformInnerPadding(minDimension: minDimension)
      let stackSpacing = platformStackSpacing(minDimension: minDimension)
      let coverWidth = platformCoverWidth(minDimension: minDimension)

      return NativeEndPageLayoutMetrics(
        outerPadding: outerPadding,
        innerPadding: innerPadding,
        stackSpacing: stackSpacing,
        portraitSectionSpacing: stackSpacing + clamped(stackSpacing * 0.5, lower: 6, upper: 12),
        horizontalDividerWidth: clamped(bounds.width * 0.78, lower: 260, upper: 680),
        coverWidth: coverWidth,
        coverHeight: coverWidth / CoverAspectRatio.widthToHeight,
        dividerHeight: clamped(maxDimension * 0.32, lower: 140, upper: 320),
        badgeFont: badgeFont,
        titleFont: titleFont,
        detailFont: detailFont
      )
    }

    static var coverHeightConstraintPriority: UILayoutPriority {
      #if os(tvOS)
        .defaultHigh
      #else
        .required
      #endif
    }

    static func protectVerticalText(_ label: UILabel) {
      #if os(tvOS)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
      #endif
    }

    static func allowCoverToYieldVerticalSpace(_ view: UIView) {
      #if os(tvOS)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
      #endif
    }

    private static var badgeFont: UIFont {
      #if os(tvOS)
        .preferredFont(forTextStyle: .caption2)
      #else
        preferredFont(textStyle: .caption1, weight: .semibold)
      #endif
    }

    private static var titleFont: UIFont {
      #if os(tvOS)
        .preferredFont(forTextStyle: .headline)
      #else
        preferredFont(textStyle: .title3, design: .serif, weight: .bold)
      #endif
    }

    private static var detailFont: UIFont {
      #if os(tvOS)
        .preferredFont(forTextStyle: .caption2)
      #else
        .preferredFont(forTextStyle: .caption1)
      #endif
    }

    private static func platformOuterPadding(minDimension: CGFloat) -> CGFloat {
      #if os(tvOS)
        clamped(minDimension * 0.045, lower: 20, upper: 40)
      #else
        clamped(minDimension * 0.08, lower: 20, upper: 56)
      #endif
    }

    private static func platformInnerPadding(minDimension: CGFloat) -> CGFloat {
      #if os(tvOS)
        clamped(minDimension * 0.028, lower: 14, upper: 22)
      #else
        clamped(minDimension * 0.045, lower: 16, upper: 32)
      #endif
    }

    private static func platformStackSpacing(minDimension: CGFloat) -> CGFloat {
      #if os(tvOS)
        clamped(minDimension * 0.022, lower: 10, upper: 16)
      #else
        clamped(minDimension * 0.034, lower: 12, upper: 22)
      #endif
    }

    private static func platformCoverWidth(minDimension: CGFloat) -> CGFloat {
      #if os(tvOS)
        clamped(minDimension * 0.18, lower: 100, upper: 150)
      #else
        clamped(minDimension * 0.24, lower: 96, upper: 190)
      #endif
    }

    private static func preferredFont(
      textStyle: UIFont.TextStyle,
      design: UIFontDescriptor.SystemDesign? = nil,
      weight: UIFont.Weight? = nil
    ) -> UIFont {
      var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
      if let design, let designedDescriptor = descriptor.withDesign(design) {
        descriptor = designedDescriptor
      }
      if let weight {
        descriptor = descriptor.addingAttributes([
          UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
      }
      return UIFont(descriptor: descriptor, size: 0)
    }

    private static func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
      Swift.min(Swift.max(value, lower), upper)
    }
  }
#endif
