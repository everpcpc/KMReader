#if os(iOS)
  import Foundation

  enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case classic = "AppIconClassic"
    case reverse = "AppIconReverse"
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
      case .reverse:
        return String(localized: "Reverse")
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
      case .reverse:
        return AppIconOption.reverse.rawValue
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
      case .reverse:
        return "logoReverse"
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
      case "AppIconReverse", "AppIconReverseAlt", AppIconOption.reverse.rawValue:
        return .reverse
      case "AppIconGlass", "AppIconGlassAlt", AppIconOption.glass.rawValue:
        return .glass
      default:
        break
      }

      return allCases.first { $0.alternateIconName == alternateIconName } ?? .primary
    }
  }
#endif
