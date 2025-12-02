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

  static var maxDiskCacheSize: Int {
    get {
      if defaults.object(forKey: "maxDiskCacheSize") != nil {
        return defaults.integer(forKey: "maxDiskCacheSize")
      }
      return 8  // Default 8 GB
    }
    set { defaults.set(newValue, forKey: "maxDiskCacheSize") }
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

  static var enableSSENotify: Bool {
    get {
      if defaults.object(forKey: "enableSSENotify") != nil {
        return defaults.bool(forKey: "enableSSENotify")
      }
      return false  // Default to disabled
    }
    set { defaults.set(newValue, forKey: "enableSSENotify") }
  }

  static var enableSSEAutoRefresh: Bool {
    get {
      if defaults.object(forKey: "enableSSEAutoRefresh") != nil {
        return defaults.bool(forKey: "enableSSEAutoRefresh")
      }
      return true  // Default to enabled
    }
    set { defaults.set(newValue, forKey: "enableSSEAutoRefresh") }
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

  static var serverLastUpdate: Date? {
    get {
      guard let timeInterval = defaults.object(forKey: "serverLastUpdate") as? TimeInterval else {
        return nil
      }
      return Date(timeIntervalSince1970: timeInterval)
    }
    set {
      if let date = newValue {
        defaults.set(date.timeIntervalSince1970, forKey: "serverLastUpdate")
      } else {
        defaults.removeObject(forKey: "serverLastUpdate")
      }
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

  // MARK: - Appearance
  static var themeColor: ThemeColor {
    get {
      if let stored = defaults.string(forKey: "themeColorHex"),
        let color = ThemeColor(rawValue: stored)
      {
        return color
      }
      return .orange
    }
    set {
      defaults.set(newValue.rawValue, forKey: "themeColorHex")
    }
  }

  static var browseLayout: BrowseLayoutMode {
    get {
      if let stored = defaults.string(forKey: "browseLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .grid
    }
    set {
      defaults.set(newValue.rawValue, forKey: "browseLayout")
    }
  }

  static var browseColumns: BrowseColumns {
    get {
      if let stored = defaults.string(forKey: "browseColumns"),
        let columns = BrowseColumns(rawValue: stored)
      {
        return columns
      }
      return BrowseColumns()
    }
    set {
      defaults.set(newValue.rawValue, forKey: "browseColumns")
    }
  }

  static var showSeriesCardTitle: Bool {
    get {
      if defaults.object(forKey: "showSeriesCardTitle") != nil {
        return defaults.bool(forKey: "showSeriesCardTitle")
      }
      return true
    }
    set {
      defaults.set(newValue, forKey: "showSeriesCardTitle")
    }
  }

  static var showBookCardSeriesTitle: Bool {
    get {
      if defaults.object(forKey: "showBookCardSeriesTitle") != nil {
        return defaults.bool(forKey: "showBookCardSeriesTitle")
      }
      return true
    }
    set {
      defaults.set(newValue, forKey: "showBookCardSeriesTitle")
    }
  }

  static var thumbnailPreserveAspectRatio: Bool {
    get {
      if defaults.object(forKey: "thumbnailPreserveAspectRatio") != nil {
        return defaults.bool(forKey: "thumbnailPreserveAspectRatio")
      }
      return true
    }
    set {
      defaults.set(newValue, forKey: "thumbnailPreserveAspectRatio")
    }
  }

  // MARK: - Reader
  static var showReaderHelperOverlay: Bool {
    get {
      if defaults.object(forKey: "showReaderHelperOverlay") != nil {
        return defaults.bool(forKey: "showReaderHelperOverlay")
      }
      return true
    }
    set {
      defaults.set(newValue, forKey: "showReaderHelperOverlay")
    }
  }

  static var readerBackground: ReaderBackground {
    get {
      if let stored = defaults.string(forKey: "readerBackground"),
        let background = ReaderBackground(rawValue: stored)
      {
        return background
      }
      return .system
    }
    set {
      defaults.set(newValue.rawValue, forKey: "readerBackground")
    }
  }

  static var pageLayout: PageLayout {
    get {
      if let stored = defaults.string(forKey: "pageLayout"),
        let layout = PageLayout(rawValue: stored)
      {
        return layout
      }
      return .dual
    }
    set {
      defaults.set(newValue.rawValue, forKey: "pageLayout")
    }
  }

  static var defaultReadingDirection: ReadingDirection {
    get {
      if let stored = defaults.string(forKey: "defaultReadingDirection"),
        let direction = ReadingDirection(rawValue: stored)
      {
        return direction
      }
      return .ltr
    }
    set {
      defaults.set(newValue.rawValue, forKey: "defaultReadingDirection")
    }
  }

  static var webtoonPageWidthPercentage: Double {
    get {
      if defaults.object(forKey: "webtoonPageWidthPercentage") != nil {
        return defaults.double(forKey: "webtoonPageWidthPercentage")
      }
      return 100.0
    }
    set {
      defaults.set(newValue, forKey: "webtoonPageWidthPercentage")
    }
  }

  // MARK: - Dashboard
  static var dashboard: DashboardConfiguration {
    get {
      if let stored = defaults.string(forKey: "dashboard"),
        let config = DashboardConfiguration(rawValue: stored)
      {
        return config
      }
      return DashboardConfiguration()
    }
    set {
      defaults.set(newValue.rawValue, forKey: "dashboard")
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
    serverLastUpdate = nil
  }
}
