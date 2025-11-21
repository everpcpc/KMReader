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

  // MARK: - Clear all auth data
  static func clearAuthData() {
    authToken = nil
    username = nil
    isLoggedIn = false
  }
}
