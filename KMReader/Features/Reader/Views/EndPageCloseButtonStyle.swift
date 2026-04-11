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
      button.layer.shadowColor = UIColor.black.withAlphaComponent(0.35).cgColor
      button.layer.shadowOpacity = 1
      button.layer.shadowRadius = 4
      button.layer.shadowOffset = CGSize(width: 0, height: 2)
      button.layer.masksToBounds = false
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
