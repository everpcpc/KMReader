#if os(iOS) || os(tvOS)
  import UIKit

  enum EndPageCloseButtonStyle {
    static func apply(to button: UIButton, textColor: UIColor) {
      var configuration = borderedButtonConfiguration()
      configuration.image = UIImage(systemName: "xmark")
      configuration.imagePlacement = .leading
      configuration.imagePadding = 8
      configuration.preferredSymbolConfigurationForImage = buttonSymbolConfiguration
      configuration.title = String(localized: "Close")
      configuration.cornerStyle = .capsule
      button.configuration = configuration
      button.tintColor = textColor
    }

    private static func borderedButtonConfiguration() -> UIButton.Configuration {
      #if os(iOS)
        if #available(iOS 26.0, *) {
          return .glass()
        }
      #endif
      return .bordered()
    }

    private static var buttonSymbolConfiguration: UIImage.SymbolConfiguration {
      UIImage.SymbolConfiguration(
        textStyle: .subheadline,
        scale: .small
      )
    }
  }
#elseif os(macOS)
  import AppKit

  enum EndPageCloseButtonStyle {
    static func apply(to button: NSButton, textColor: NSColor) {
      button.title = String(localized: "Close")
      button.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
      button.imagePosition = .imageLeading
      button.contentTintColor = textColor
    }
  }
#endif
