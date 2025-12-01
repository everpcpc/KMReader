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

  static var serverDisplayName: String {
    get { defaults.string(forKey: "serverDisplayName") ?? "" }
    set { defaults.set(newValue, forKey: "serverDisplayName") }
  }

  static var authToken: String {
    get { defaults.string(forKey: "authToken") ?? "" }
    set { defaults.set(newValue, forKey: "authToken") }
  }

  static var username: String {
    get { defaults.string(forKey: "username") ?? "" }
    set { defaults.set(newValue, forKey: "username") }
  }

  static var isLoggedIn: Bool {
    get { defaults.bool(forKey: "isLoggedIn") }
    set { defaults.set(newValue, forKey: "isLoggedIn") }
  }

  static var isAdmin: Bool {
    get { defaults.bool(forKey: "isAdmin") }
    set { defaults.set(newValue, forKey: "isAdmin") }
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

  static var currentInstanceId: String {
    get { defaults.string(forKey: "currentInstanceId") ?? "" }
    set { defaults.set(newValue, forKey: "currentInstanceId") }
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

  // MARK: - SSE (Server-Sent Events)
  static var enableSSE: Bool {
    get {
      if defaults.object(forKey: "enableSSE") != nil {
        return defaults.bool(forKey: "enableSSE")
      }
      return true  // Default to enabled
    }
    set { defaults.set(newValue, forKey: "enableSSE") }
  }

  static var enableSSENotifications: Bool {
    get {
      if defaults.object(forKey: "enableSSENotifications") != nil {
        return defaults.bool(forKey: "enableSSENotifications")
      }
      return true  // Default to enabled
    }
    set { defaults.set(newValue, forKey: "enableSSENotifications") }
  }

  static var taskQueueStatus: TaskQueueSSEDto {
    get {
      guard let rawValue = defaults.string(forKey: "taskQueueStatus"),
        !rawValue.isEmpty,
        let status = TaskQueueSSEDto(rawValue: rawValue)
      else {
        return TaskQueueSSEDto()
      }
      return status
    }
    set {
      defaults.set(newValue.rawValue, forKey: "taskQueueStatus")
    }
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

  // MARK: - Clear selected library IDs
  static func clearSelectedLibraryIds() {
    if let rawValue = defaults.string(forKey: "dashboard"),
      var config = DashboardConfiguration(rawValue: rawValue)
    {
      config.libraryIds = []
      defaults.set(config.rawValue, forKey: "dashboard")
    }
  }

  // MARK: - Clear all auth data
  static func clearAuthData() {
    authToken = ""
    username = ""
    serverDisplayName = ""
    isAdmin = false
    clearSelectedLibraryIds()
    currentInstanceId = ""
  }
}
