import Foundation

#if os(iOS)
  import UIKit
#endif

enum AppIconLogoAsset {
  static var current: String {
    #if os(iOS)
      AppIconOption.from(alternateIconName: UIApplication.shared.alternateIconName).logoAssetName
    #else
      "logo"
    #endif
  }
}
