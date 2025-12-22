//
//  PlatformHelpers.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

#if os(iOS) || os(tvOS)
  import UIKit
  public typealias PlatformImage = UIImage
  #if os(iOS)
    /// Pasteboard type for iOS platforms
    public typealias PlatformPasteboard = UIPasteboard
  #endif
#elseif os(macOS)
  import AppKit
  public typealias PlatformImage = NSImage
  /// Pasteboard type for macOS platforms
  public typealias PlatformPasteboard = NSPasteboard
#endif

/// Platform helper for device information and UI idioms
struct PlatformHelper {
  /// Get device model name
  static var deviceModel: String {
    #if os(iOS)
      return UIDevice.current.model
    #elseif os(macOS)
      return "Mac"
    #else
      return "Unknown"
    #endif
  }

  /// Get OS version string
  static var osVersion: String {
    #if os(iOS)
      return UIDevice.current.systemVersion
    #elseif os(macOS)
      let version = ProcessInfo.processInfo.operatingSystemVersion
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #else
      let version = ProcessInfo.processInfo.operatingSystemVersion
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #endif
  }

  /// Persistent, per-installation identifier used when reporting reading positions.
  static var deviceIdentifier: String {
    if let cached = AppConfig.deviceIdentifier, !cached.isEmpty {
      return cached
    }
    #if os(iOS)
      if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
        AppConfig.deviceIdentifier = vendorId
        return vendorId
      }
    #endif
    let fallback = UUID().uuidString
    AppConfig.deviceIdentifier = fallback
    return fallback
  }

  /// Check if running on iPad
  static var isPad: Bool {
    #if os(iOS)
      return UIDevice.current.userInterfaceIdiom == .pad
    #else
      return false
    #endif
  }

  /// Get dashboard card width based on platform
  /// - iOS (iPhone): 120
  /// - iOS (iPad): 160
  /// - macOS: 160
  /// - tvOS: 240
  static var dashboardCardWidth: CGFloat {
    #if os(tvOS)
      return 240
    #elseif os(macOS)
      return 160
    #elseif os(iOS)
      return isPad ? 160 : 120
    #else
      return 120
    #endif
  }

  static var sheetPadding: CGFloat {
    #if os(tvOS)
      return 24
    #elseif os(macOS)
      return 16
    #else
      return 8
    #endif
  }

  static var buttonSpacing: CGFloat {
    #if os(tvOS)
      return 36
    #elseif os(macOS)
      return 24
    #else
      return 12
    #endif
  }

  static var iconSize: CGFloat {
    #if os(tvOS)
      return 24
    #elseif os(macOS)
      return 14
    #else
      return 12
    #endif
  }

  static var detailThumbnailWidth: CGFloat {
    #if os(tvOS)
      return 240
    #elseif os(macOS)
      return 180
    #else
      return 120
    #endif
  }

  static var progressBarHeight: CGFloat {
    #if os(tvOS)
      return 6
    #elseif os(macOS)
      return 4
    #elseif os(iOS)
      return isPad ? 4 : 3
    #else
      return 4
    #endif
  }

  /// Get device orientation
  /// - iOS: use `UIDevice.current.orientation`
  /// - tvOS / macOS: always return `.landscape`
  /// - Others: `.unknown`
  static var deviceOrientation: DeviceOrientation {
    #if os(tvOS) || os(macOS)
      return .landscape
    #elseif os(iOS)
      let orientation = UIDevice.current.orientation
      if orientation.isLandscape {
        return .landscape
      } else if orientation.isPortrait {
        return .portrait
      } else {
        return .unknown
      }
    #else
      return .unknown
    #endif
  }

  #if os(iOS) || os(macOS)
    /// Get pasteboard for copying text (iOS and macOS only)
    static var generalPasteboard: PlatformPasteboard {
      #if os(iOS)
        return UIPasteboard.general
      #elseif os(macOS)
        return NSPasteboard.general
      #endif
    }
  #endif

  /// Convert SwiftUI Color to CGColor
  /// - Parameter color: SwiftUI Color to convert
  /// - Returns: CGColor representation of the color
  static func cgColor(from color: Color) -> CGColor {
    #if os(iOS) || os(tvOS)
      return UIColor(color).cgColor
    #elseif os(macOS)
      return NSColor(color).cgColor
    #else
      // Fallback: use default orange color
      return CGColor(red: 1, green: 0.58, blue: 0, alpha: 1)
    #endif
  }

  /// Get system background color
  /// - Returns: System background color appropriate for the platform
  static var systemBackgroundColor: Color {
    #if os(iOS)
      return Color(.systemBackground)
    #elseif os(macOS)
      return Color(NSColor.controlBackgroundColor)
    #else
      return .gray
    #endif
  }

  /// Get secondary system background color
  /// - Returns: Secondary system background color appropriate for the platform
  static var secondarySystemBackgroundColor: Color {
    #if os(iOS)
      return Color(.secondarySystemBackground)
    #elseif os(macOS)
      return Color(NSColor.controlBackgroundColor).opacity(0.5)
    #else
      return .gray.opacity(0.5)
    #endif
  }

  /// Convert PlatformImage to PNG data
  /// - Parameter image: Platform image to convert
  /// - Returns: PNG data if conversion succeeds, nil otherwise
  static func pngData(from image: PlatformImage) -> Data? {
    #if os(iOS)
      return image.pngData()
    #elseif os(macOS)
      guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
      }
      let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
      return bitmapRep.representation(using: .png, properties: [:])
    #else
      return nil
    #endif
  }
}

enum DeviceOrientation {
  case portrait
  case landscape
  case unknown

  var isLandscape: Bool {
    self == .landscape
  }

  var isPortrait: Bool {
    self == .portrait
  }
}

#if os(macOS)
  extension NSPasteboard {
    var string: String? {
      get {
        return self.string(forType: .string)
      }
      set {
        if let value = newValue {
          self.clearContents()
          self.setString(value, forType: .string)
        }
      }
    }
  }
#endif
