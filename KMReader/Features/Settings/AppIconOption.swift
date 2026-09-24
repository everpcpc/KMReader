#if os(iOS)
  import Foundation

  enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case classic = "AppIconClassic"
    case legacy = "AppIconLegacy"
    case reverse = "AppIconReverse"

    var id: String {
      rawValue
    }

    var title: String {
      switch self {
      case .primary:
        return String(localized: "Default")
      case .classic:
        return String(localized: "Classic")
      case .legacy:
        return String(localized: "Legacy")
      case .reverse:
        return String(localized: "Reverse")
      }
    }

    var alternateIconName: String? {
      switch self {
      case .primary:
        return nil
      case .classic:
        return AppIconOption.classic.rawValue
      case .legacy:
        return AppIconOption.legacy.rawValue
      case .reverse:
        return AppIconOption.reverse.rawValue
      }
    }

    var logoAssetName: String {
      switch self {
      case .primary:
        return "logo"
      case .classic:
        return "logoClassic"
      case .legacy:
        return "logoLegacy"
      case .reverse:
        return "logoReverse"
      }
    }

    static func from(alternateIconName: String?) -> AppIconOption {
      guard let alternateIconName else {
        return .primary
      }

      switch alternateIconName {
      case "AppIconClassic", "AppIconClassicAlt", AppIconOption.classic.rawValue:
        return .classic
      case "AppIconLegacy", AppIconOption.legacy.rawValue:
        return .legacy
      case "AppIconReverse", "AppIconReverseAlt", "AppIconGlass", "AppIconGlassAlt",
        AppIconOption.reverse.rawValue:
        return .reverse
      default:
        break
      }

      return allCases.first { $0.alternateIconName == alternateIconName } ?? .primary
    }
  }
#endif
