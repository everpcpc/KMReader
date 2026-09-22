#if os(iOS)
  import Foundation

  enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case classic = "AppIconClassic"
    case legacy = "AppIconLegacy"
    case glass = "AppIconGlass"

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
      case .glass:
        return String(localized: "Glass")
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
      case .glass:
        return AppIconOption.glass.rawValue
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
      case .glass:
        return "logoGlass"
      }
    }

    static func from(alternateIconName: String?) -> AppIconOption {
      guard let alternateIconName else {
        return .primary
      }

      switch alternateIconName {
      case "AppIconClassic", "AppIconClassicAlt", AppIconOption.classic.rawValue:
        return .classic
      case "AppIconReverse", "AppIconReverseAlt":
        return .primary
      case "AppIconLegacy", AppIconOption.legacy.rawValue:
        return .legacy
      case "AppIconGlass", "AppIconGlassAlt", AppIconOption.glass.rawValue:
        return .glass
      default:
        break
      }

      return allCases.first { $0.alternateIconName == alternateIconName } ?? .primary
    }
  }
#endif
