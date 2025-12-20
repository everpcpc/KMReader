//
//  AppConfig.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

/// Centralized configuration management using UserDefaults
enum AppConfig {

  // MARK: - Server & Auth
  static var serverURL: String {
    get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "serverURL") }
  }

  static var serverDisplayName: String {
    get { UserDefaults.standard.string(forKey: "serverDisplayName") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "serverDisplayName") }
  }

  static var authToken: String {
    get { UserDefaults.standard.string(forKey: "authToken") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "authToken") }
  }

  static var authMethod: AuthenticationMethod {
    get {
      if let stored = UserDefaults.standard.string(forKey: "authMethod"),
        let method = AuthenticationMethod(rawValue: stored)
      {
        return method
      }
      return .basicAuth
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: "authMethod") }
  }

  static var username: String {
    get { UserDefaults.standard.string(forKey: "username") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "username") }
  }

  static var isLoggedIn: Bool {
    get { UserDefaults.standard.bool(forKey: "isLoggedIn") }
    set { UserDefaults.standard.set(newValue, forKey: "isLoggedIn") }
  }

  static var isAdmin: Bool {
    get { UserDefaults.standard.bool(forKey: "isAdmin") }
    set { UserDefaults.standard.set(newValue, forKey: "isAdmin") }
  }

  static var deviceIdentifier: String? {
    get { UserDefaults.standard.string(forKey: "deviceIdentifier") }
    set {
      if let value = newValue {
        UserDefaults.standard.set(value, forKey: "deviceIdentifier")
      } else {
        UserDefaults.standard.removeObject(forKey: "deviceIdentifier")
      }
    }
  }

  static var dualPageNoCover: Bool {
    get { UserDefaults.standard.bool(forKey: "dualPageNoCover") }
    set { UserDefaults.standard.set(newValue, forKey: "dualPageNoCover") }
  }

  static nonisolated var currentInstanceId: String {
    get { UserDefaults.standard.string(forKey: "currentInstanceId") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "currentInstanceId") }
  }

  static nonisolated var maxPageCacheSize: Int {
    get {
      if UserDefaults.standard.object(forKey: "maxPageCacheSize") != nil {
        return UserDefaults.standard.integer(forKey: "maxPageCacheSize")
      }
      return 8  // Default 8 GB
    }
    set { UserDefaults.standard.set(newValue, forKey: "maxPageCacheSize") }
  }

  static nonisolated var maxThumbnailCacheSize: Int {
    get {
      if UserDefaults.standard.object(forKey: "maxThumbnailCacheSize") != nil {
        return UserDefaults.standard.integer(forKey: "maxThumbnailCacheSize")
      }
      return 1  // Default 1 GB
    }
    set { UserDefaults.standard.set(newValue, forKey: "maxThumbnailCacheSize") }
  }

  // MARK: - SSE (Server-Sent Events)
  static var enableSSE: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSE") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSE")
      }
      return true  // Default to enabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSE") }
  }

  static var enableSSENotify: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSENotify") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSENotify")
      }
      return false  // Default to disabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSENotify") }
  }

  static var enableSSEAutoRefresh: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSEAutoRefresh") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSEAutoRefresh")
      }
      return true  // Default to enabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSEAutoRefresh") }
  }

  static var taskQueueStatus: TaskQueueSSEDto {
    get {
      guard let rawValue = UserDefaults.standard.string(forKey: "taskQueueStatus"),
        !rawValue.isEmpty,
        let status = TaskQueueSSEDto(rawValue: rawValue)
      else {
        return TaskQueueSSEDto()
      }
      return status
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "taskQueueStatus")
    }
  }

  static nonisolated var offlinePaused: Bool {
    get { UserDefaults.standard.bool(forKey: "offlinePaused") }
    set { UserDefaults.standard.set(newValue, forKey: "offlinePaused") }
  }

  // MARK: - Dashboard

  static var dashboardConfiguration: DashboardConfiguration {
    get {
      guard let rawValue = UserDefaults.standard.string(forKey: "dashboard"),
        let config = DashboardConfiguration(rawValue: rawValue)
      else {
        return DashboardConfiguration()
      }
      return config
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "dashboard")
    }
  }

  static var serverLastUpdate: Date? {
    get {
      guard
        let timeInterval = UserDefaults.standard.object(forKey: "serverLastUpdate") as? TimeInterval
      else {
        return nil
      }
      return Date(timeIntervalSince1970: timeInterval)
    }
    set {
      if let date = newValue {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "serverLastUpdate")
      } else {
        UserDefaults.standard.removeObject(forKey: "serverLastUpdate")
      }
    }
  }

  // MARK: - Custom Fonts
  static var customFontNames: [String] {
    get {
      UserDefaults.standard.stringArray(forKey: "customFontNames") ?? []
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "customFontNames")
    }
  }

  // MARK: - Appearance
  static var themeColor: ThemeColor {
    get {
      if let stored = UserDefaults.standard.string(forKey: "themeColorHex"),
        let color = ThemeColor(rawValue: stored)
      {
        return color
      }
      return .orange
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "themeColorHex")
    }
  }

  // MARK: - Browse Layouts
  static var seriesBrowseLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "seriesBrowseLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .grid
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "seriesBrowseLayout")
    }
  }

  static var collectionBrowseLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "collectionBrowseLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .grid
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "collectionBrowseLayout")
    }
  }

  static var bookBrowseLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "bookBrowseLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .grid
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "bookBrowseLayout")
    }
  }

  static var readListBrowseLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "readListBrowseLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .grid
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "readListBrowseLayout")
    }
  }

  // MARK: - Detail Layouts
  static var seriesDetailLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "seriesDetailLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .list
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "seriesDetailLayout")
    }
  }

  static var collectionDetailLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "collectionDetailLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .list
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "collectionDetailLayout")
    }
  }

  static var readListDetailLayout: BrowseLayoutMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "readListDetailLayout"),
        let layout = BrowseLayoutMode(rawValue: stored)
      {
        return layout
      }
      return .list
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "readListDetailLayout")
    }
  }

  static var browseColumns: BrowseColumns {
    get {
      if let stored = UserDefaults.standard.string(forKey: "browseColumns"),
        let columns = BrowseColumns(rawValue: stored)
      {
        return columns
      }
      return BrowseColumns()
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "browseColumns")
    }
  }

  static var showSeriesCardTitle: Bool {
    get {
      if UserDefaults.standard.object(forKey: "showSeriesCardTitle") != nil {
        return UserDefaults.standard.bool(forKey: "showSeriesCardTitle")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "showSeriesCardTitle")
    }
  }

  static var showBookCardSeriesTitle: Bool {
    get {
      if UserDefaults.standard.object(forKey: "showBookCardSeriesTitle") != nil {
        return UserDefaults.standard.bool(forKey: "showBookCardSeriesTitle")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "showBookCardSeriesTitle")
    }
  }

  static var thumbnailPreserveAspectRatio: Bool {
    get {
      if UserDefaults.standard.object(forKey: "thumbnailPreserveAspectRatio") != nil {
        return UserDefaults.standard.bool(forKey: "thumbnailPreserveAspectRatio")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "thumbnailPreserveAspectRatio")
    }
  }

  static var searchIgnoreFilters: Bool {
    get {
      if UserDefaults.standard.object(forKey: "searchIgnoreFilters") != nil {
        return UserDefaults.standard.bool(forKey: "searchIgnoreFilters")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "searchIgnoreFilters")
    }
  }

  // MARK: - Reader
  static var showTapZoneHints: Bool {
    get {
      if UserDefaults.standard.object(forKey: "showTapZoneHints") != nil {
        return UserDefaults.standard.bool(forKey: "showTapZoneHints")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "showTapZoneHints")
    }
  }

  static var disableTapToTurnPage: Bool {
    get {
      if UserDefaults.standard.object(forKey: "disableTapToTurnPage") != nil {
        return UserDefaults.standard.bool(forKey: "disableTapToTurnPage")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "disableTapToTurnPage")
    }
  }

  static var showKeyboardHelpOverlay: Bool {
    get {
      if UserDefaults.standard.object(forKey: "showKeyboardHelpOverlay") != nil {
        return UserDefaults.standard.bool(forKey: "showKeyboardHelpOverlay")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "showKeyboardHelpOverlay")
    }
  }

  static var readerBackground: ReaderBackground {
    get {
      if let stored = UserDefaults.standard.string(forKey: "readerBackground"),
        let background = ReaderBackground(rawValue: stored)
      {
        return background
      }
      return .system
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "readerBackground")
    }
  }

  static var pageLayout: PageLayout {
    get {
      if let stored = UserDefaults.standard.string(forKey: "pageLayout") {
        if stored == "dual" {
          return .auto
        }
        if let layout = PageLayout(rawValue: stored) {
          return layout
        }
      }
      return .auto
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "pageLayout")
    }
  }

  static var defaultReadingDirection: ReadingDirection {
    get {
      if let stored = UserDefaults.standard.string(forKey: "defaultReadingDirection"),
        let direction = ReadingDirection(rawValue: stored)
      {
        return direction
      }
      return .ltr
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "defaultReadingDirection")
    }
  }

  static var webtoonPageWidthPercentage: Double {
    get {
      if UserDefaults.standard.object(forKey: "webtoonPageWidthPercentage") != nil {
        return UserDefaults.standard.double(forKey: "webtoonPageWidthPercentage")
      }
      return 100.0
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "webtoonPageWidthPercentage")
    }
  }

  static var showPageNumber: Bool {
    get {
      if UserDefaults.standard.object(forKey: "showPageNumber") != nil {
        return UserDefaults.standard.bool(forKey: "showPageNumber")
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "showPageNumber")
    }
  }

  static var pageTransitionStyle: PageTransitionStyle {
    get {
      if let stored = UserDefaults.standard.string(forKey: "pageTransitionStyle"),
        let style = PageTransitionStyle(rawValue: stored)
      {
        return style
      }
      return .simple
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "pageTransitionStyle")
    }
  }

  static var doubleTapZoomScale: Double {
    get {
      if UserDefaults.standard.object(forKey: "doubleTapZoomScale") != nil {
        return UserDefaults.standard.double(forKey: "doubleTapZoomScale")
      }
      return 2.0
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "doubleTapZoomScale")
    }
  }

  // MARK: - Dashboard
  static var dashboard: DashboardConfiguration {
    get {
      if let stored = UserDefaults.standard.string(forKey: "dashboard"),
        let config = DashboardConfiguration(rawValue: stored)
      {
        return config
      }
      return DashboardConfiguration()
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "dashboard")
    }
  }

  // MARK: - Clear selected library IDs
  static func clearSelectedLibraryIds() {
    if let rawValue = UserDefaults.standard.string(forKey: "dashboard"),
      var config = DashboardConfiguration(rawValue: rawValue)
    {
      config.libraryIds = []
      UserDefaults.standard.set(config.rawValue, forKey: "dashboard")
    }
  }

  // MARK: - Clear all auth data
  static func clearAuthData() {
    authToken = ""
    authMethod = .basicAuth
    username = ""
    serverDisplayName = ""
    isAdmin = false
    clearSelectedLibraryIds()
    currentInstanceId = ""
    serverLastUpdate = nil
  }
}
