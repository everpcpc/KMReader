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

#if os(iOS) || os(tvOS)
  import Darwin
#endif

/// Platform helper for device information and UI idioms
enum PlatformHelper {

  /// Initialize cached values that require MainActor
  @MainActor
  static func setup() {
    // 1. Detect device model
    let detectedModel: String
    #if os(iOS) || os(tvOS)
      var systemInfo = utsname()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      detectedModel = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
    #elseif os(macOS)
      detectedModel = "Mac"
    #else
      detectedModel = "Unknown"
    #endif
    AppConfig.deviceModel = detectedModel

    // 2. Detect OS version
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let detectedOS = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    AppConfig.osVersion = detectedOS

    // 3. Handle device identifier
    let storedId = AppConfig.deviceIdentifier
    if storedId.isEmpty {
      var newId: String?
      #if os(iOS)
        newId = UIDevice.current.identifierForVendor?.uuidString
      #endif
      let finalId = newId ?? UUID().uuidString
      AppConfig.deviceIdentifier = finalId
    }
  }

  /// Get device model name
  static nonisolated var deviceModel: String {
    AppConfig.deviceModel
  }

  /// Get OS version string
  static nonisolated var osVersion: String {
    AppConfig.osVersion
  }

  /// Persistent, per-installation identifier used when reporting reading positions.
  static nonisolated var deviceIdentifier: String {
    AppConfig.deviceIdentifier
  }

  /// Check if running on iPad
  @MainActor
  static var isPad: Bool {
    #if os(iOS)
      return UIDevice.current.userInterfaceIdiom == .pad
    #else
      return false
    #endif
  }

  @MainActor
  static var defaultDashboardCardWidth: CGFloat {
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

  @MainActor
  static var sheetPadding: CGFloat {
    #if os(tvOS)
      return 24
    #elseif os(macOS)
      return 16
    #else
      return 8
    #endif
  }

  @MainActor
  static var buttonSpacing: CGFloat {
    #if os(tvOS)
      return 36
    #elseif os(macOS)
      return 24
    #else
      return 12
    #endif
  }

  @MainActor
  static var iconSize: CGFloat {
    #if os(tvOS)
      return 24
    #elseif os(macOS)
      return 14
    #else
      return 12
    #endif
  }

  @MainActor
  static var detailThumbnailWidth: CGFloat {
    #if os(tvOS)
      return 240
    #elseif os(macOS)
      return 180
    #else
      return 120
    #endif
  }

  @MainActor
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
  @MainActor
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
    static nonisolated var generalPasteboard: PlatformPasteboard {
      #if os(iOS)
        return UIPasteboard.general
      #elseif os(macOS)
        return NSPasteboard.general
      #endif
    }
  #endif

  /// Get the maximum dimension of the screen to validate geometry values
  @MainActor
  static var maxScreenDimension: CGFloat {
    #if os(iOS) || os(tvOS)
      let bounds = UIScreen.main.bounds
      return max(bounds.width, bounds.height)
    #elseif os(macOS)
      if let screen = NSScreen.main {
        return max(screen.frame.width, screen.frame.height)
      }
      return 3000
    #else
      return 3000
    #endif
  }

  /// Check if a width value is valid (not anomalously large during app transitions)
  @MainActor
  static func isValidWidth(_ width: CGFloat) -> Bool {
    return width <= maxScreenDimension * 1.2
  }

  /// Convert SwiftUI Color to CGColor
  /// - Parameter color: SwiftUI Color to convert
  /// - Returns: CGColor representation of the color
  static nonisolated func cgColor(from color: Color) -> CGColor {
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
  static nonisolated var systemBackgroundColor: Color {
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
  static nonisolated var secondarySystemBackgroundColor: Color {
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
  static nonisolated func pngData(from image: PlatformImage) -> Data? {
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

extension Image {
  /// Create a SwiftUI Image from a PlatformImage (UIImage on iOS/tvOS, NSImage on macOS)
  init(platformImage: PlatformImage) {
    #if os(iOS) || os(tvOS)
      self.init(uiImage: platformImage)
    #elseif os(macOS)
      self.init(nsImage: platformImage)
    #endif
  }
}
