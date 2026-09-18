//
// PlatformFont+MonospacedDigits.swift
//
//

#if os(iOS) || os(tvOS)
  import CoreText
  import UIKit

  extension UIFont {
    /// Same font with equal-width digits, so live-updating readouts (percent,
    /// counters) don't resize as their value changes.
    var withMonospacedDigits: UIFont {
      let descriptor = fontDescriptor.addingAttributes([
        UIFontDescriptor.AttributeName.featureSettings: [
          [
            UIFontDescriptor.FeatureKey(kCTFontFeatureTypeIdentifierKey): kNumberSpacingType,
            UIFontDescriptor.FeatureKey(kCTFontFeatureSelectorIdentifierKey): kMonospacedNumbersSelector,
          ]
        ]
      ])
      return UIFont(descriptor: descriptor, size: pointSize)
    }
  }
#elseif os(macOS)
  import AppKit

  extension NSFont {
    /// Same size with equal-width digits, so live-updating readouts (percent,
    /// counters) don't resize as their value changes.
    var withMonospacedDigits: NSFont {
      NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
    }
  }
#endif
