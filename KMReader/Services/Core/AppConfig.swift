//
//  AppConfig.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

/// Centralized configuration management using UserDefaults
enum AppConfig {
  private static let defaults = UserDefaults.standard

  // MARK: - Server & Auth
  static var serverURL: String {
    get { defaults.string(forKey: "serverURL") ?? "" }
    set { defaults.set(newValue, forKey: "serverURL") }
  }

  static var authToken: String? {
    get { defaults.string(forKey: "authToken") }
    set {
      if let token = newValue {
        defaults.set(token, forKey: "authToken")
      } else {
        defaults.removeObject(forKey: "authToken")
      }
    }
  }

  static var username: String? {
    get { defaults.string(forKey: "username") }
    set {
      if let username = newValue {
        defaults.set(username, forKey: "username")
      } else {
        defaults.removeObject(forKey: "username")
      }
    }
  }

  static var isLoggedIn: Bool {
    get { defaults.bool(forKey: "isLoggedIn") }
    set { defaults.set(newValue, forKey: "isLoggedIn") }
  }

  static var isAdmin: Bool {
    get { defaults.bool(forKey: "isAdmin") }
    set { defaults.set(newValue, forKey: "isAdmin") }
  }

  static var selectedLibraryId: String {
    get { defaults.string(forKey: "selectedLibraryId") ?? "" }
    set { defaults.set(newValue, forKey: "selectedLibraryId") }
  }

  static var deviceIdentifier: String? {
    get { defaults.string(forKey: "deviceIdentifier") }
    set {
      if let value = newValue {
        defaults.set(value, forKey: "deviceIdentifier")
      } else {
        defaults.removeObject(forKey: "deviceIdentifier")
      }
    }
  }

  static var dualPageNoCover: Bool {
    get { defaults.bool(forKey: "dualPageNoCover") }
    set { defaults.set(newValue, forKey: "dualPageNoCover") }
  }

  static var maxDiskCacheSizeMB: Int {
    get {
      if defaults.object(forKey: "maxDiskCacheSizeMB") != nil {
        return defaults.integer(forKey: "maxDiskCacheSizeMB")
      }
      return 2048
    }
    set { defaults.set(newValue, forKey: "maxDiskCacheSizeMB") }
  }

  // MARK: - Custom Fonts
  static var customFontNames: [String] {
    get {
      defaults.stringArray(forKey: "customFontNames") ?? []
    }
    set {
      defaults.set(newValue, forKey: "customFontNames")
    }
  }

  // MARK: - Clear all auth data
  static func clearAuthData() {
    authToken = nil
    username = nil
    isLoggedIn = false
    isAdmin = false
    selectedLibraryId = ""
  }
}
