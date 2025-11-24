//
//  PlatformHelpers.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

#if canImport(UIKit)
  import UIKit
  public typealias PlatformImage = UIImage
  public typealias PlatformPasteboard = UIPasteboard
#elseif canImport(AppKit)
  import AppKit
  public typealias PlatformImage = NSImage
  public typealias PlatformPasteboard = NSPasteboard
#endif

/// Platform helper for device information and UI idioms
struct PlatformHelper {
  /// Get device model name
  static var deviceModel: String {
    #if canImport(UIKit)
      return UIDevice.current.model
    #elseif canImport(AppKit)
      return "Mac"
    #else
      return "Unknown"
    #endif
  }

  /// Get OS version string
  static var osVersion: String {
    #if canImport(UIKit)
      return UIDevice.current.systemVersion
    #elseif canImport(AppKit)
      let version = ProcessInfo.processInfo.operatingSystemVersion
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #else
      let version = ProcessInfo.processInfo.operatingSystemVersion
      return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #endif
  }

  /// Check if running on iPad
  static var isPad: Bool {
    #if canImport(UIKit)
      return UIDevice.current.userInterfaceIdiom == .pad
    #elseif canImport(AppKit)
      return false
    #else
      return false
    #endif
  }

  /// Check if running on macOS
  static var isMacOS: Bool {
    #if canImport(AppKit)
      return true
    #else
      return false
    #endif
  }

  /// Check if running on iOS
  static var isIOS: Bool {
    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
      return true
    #else
      return false
    #endif
  }

  /// Get device orientation (iOS only, returns portrait for macOS)
  static var deviceOrientation: DeviceOrientation {
    #if canImport(UIKit)
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

  /// Get pasteboard for copying text
  static var generalPasteboard: PlatformPasteboard {
    #if canImport(UIKit)
      return UIPasteboard.general
    #elseif canImport(AppKit)
      return NSPasteboard.general
    #else
      fatalError("Unsupported platform")
    #endif
  }

  /// Convert SwiftUI Color to CGColor
  /// - Parameter color: SwiftUI Color to convert
  /// - Returns: CGColor representation of the color
  static func cgColor(from color: Color) -> CGColor {
    #if canImport(UIKit)
      return UIColor(color).cgColor
    #elseif canImport(AppKit)
      return NSColor(color).cgColor
    #else
      // Fallback: use default orange color
      return CGColor(red: 1, green: 0.58, blue: 0, alpha: 1)!
    #endif
  }

  /// Get system background color
  /// - Returns: System background color appropriate for the platform
  static var systemBackgroundColor: Color {
    #if canImport(UIKit)
      return Color(.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.controlBackgroundColor)
    #else
      return .gray
    #endif
  }

  /// Get secondary system background color
  /// - Returns: Secondary system background color appropriate for the platform
  static var secondarySystemBackgroundColor: Color {
    #if canImport(UIKit)
      return Color(.secondarySystemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.controlBackgroundColor).opacity(0.5)
    #else
      return .gray.opacity(0.5)
    #endif
  }

  /// Convert PlatformImage to PNG data
  /// - Parameter image: Platform image to convert
  /// - Returns: PNG data if conversion succeeds, nil otherwise
  static func pngData(from image: PlatformImage) -> Data? {
    #if canImport(UIKit)
      return image.pngData()
    #elseif canImport(AppKit)
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

#if canImport(AppKit)
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
