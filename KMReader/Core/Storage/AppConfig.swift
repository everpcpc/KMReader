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
  static nonisolated var current: Current {
    get {
      if let rawValue = UserDefaults.standard.string(forKey: "currentAccount"),
        let current = Current(rawValue: rawValue)
      {
        return current
      }
      return Current()
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "currentAccount")
    }
  }

  static nonisolated var apiTimeout: Double {
    get {
      if UserDefaults.standard.object(forKey: "apiTimeout") != nil {
        return UserDefaults.standard.double(forKey: "apiTimeout")
      }
      return 10.0
    }
    set { UserDefaults.standard.set(newValue, forKey: "apiTimeout") }
  }

  static nonisolated var apiRetryCount: Int {
    get {
      if UserDefaults.standard.object(forKey: "apiRetryCount") != nil {
        return UserDefaults.standard.integer(forKey: "apiRetryCount")
      }
      return 0
    }
    set { UserDefaults.standard.set(newValue, forKey: "apiRetryCount") }
  }

  static nonisolated var isLoggedIn: Bool {
    get { UserDefaults.standard.bool(forKey: "isLoggedInV2") }
    set { UserDefaults.standard.set(newValue, forKey: "isLoggedInV2") }
  }

  static nonisolated var deviceIdentifier: String {
    get { UserDefaults.standard.string(forKey: "deviceIdentifier") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "deviceIdentifier") }
  }

  static nonisolated var deviceModel: String {
    get { UserDefaults.standard.string(forKey: "deviceModel") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "deviceModel") }
  }

  static nonisolated var osVersion: String {
    get { UserDefaults.standard.string(forKey: "osVersion") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "osVersion") }
  }

  static nonisolated var dualPageNoCover: Bool {
    get { UserDefaults.standard.bool(forKey: "dualPageNoCover") }
    set { UserDefaults.standard.set(newValue, forKey: "dualPageNoCover") }
  }

  static nonisolated var isOffline: Bool {
    get { UserDefaults.standard.bool(forKey: "isOffline") }
    set { UserDefaults.standard.set(newValue, forKey: "isOffline") }
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

  static nonisolated var maxCoverCacheSize: Int {
    get {
      if UserDefaults.standard.object(forKey: "maxCoverCacheSize") != nil {
        return UserDefaults.standard.integer(forKey: "maxCoverCacheSize")
      }
      return 512  // Default 512 MB
    }
    set { UserDefaults.standard.set(newValue, forKey: "maxCoverCacheSize") }
  }

  // MARK: - SSE (Server-Sent Events)
  static nonisolated var enableSSE: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSE") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSE")
      }
      return true  // Default to enabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSE") }
  }

  static nonisolated var enableSSENotify: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSENotify") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSENotify")
      }
      return false  // Default to disabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSENotify") }
  }

  static nonisolated var enableSSEAutoRefresh: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableSSEAutoRefresh") != nil {
        return UserDefaults.standard.bool(forKey: "enableSSEAutoRefresh")
      }
      return true  // Default to enabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "enableSSEAutoRefresh") }
  }

  static nonisolated var taskQueueStatus: TaskQueueSSEDto {
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

  static nonisolated var offlineAutoDeleteRead: Bool {
    get { UserDefaults.standard.bool(forKey: "offlineAutoDeleteRead") }
    set { UserDefaults.standard.set(newValue, forKey: "offlineAutoDeleteRead") }
  }

  static nonisolated var backgroundDownloadTasksData: Data? {
    get { UserDefaults.standard.data(forKey: "BackgroundDownloadTasks") }
    set {
      if let value = newValue {
        UserDefaults.standard.set(value, forKey: "BackgroundDownloadTasks")
      } else {
        UserDefaults.standard.removeObject(forKey: "BackgroundDownloadTasks")
      }
    }
  }

  // MARK: - Dashboard

  static nonisolated var gridDensity: Double {
    get {
      if UserDefaults.standard.object(forKey: "gridDensity") != nil {
        return UserDefaults.standard.double(forKey: "gridDensity")
      }
      return GridDensity.standard.rawValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "gridDensity")
    }
  }

  static nonisolated var serverLastUpdate: Date? {
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
  static nonisolated var customFontNames: [String] {
    get {
      UserDefaults.standard.stringArray(forKey: "customFontNames") ?? []
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "customFontNames")
    }
  }

  // MARK: - Appearance
  static nonisolated var themeColor: ThemeColor {
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
  static nonisolated var seriesBrowseLayout: BrowseLayoutMode {
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

  static nonisolated var collectionBrowseLayout: BrowseLayoutMode {
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

  static nonisolated var bookBrowseLayout: BrowseLayoutMode {
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

  static nonisolated var readListBrowseLayout: BrowseLayoutMode {
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
  static nonisolated var seriesDetailLayout: BrowseLayoutMode {
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

  static nonisolated var collectionDetailLayout: BrowseLayoutMode {
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

  static nonisolated var readListDetailLayout: BrowseLayoutMode {
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

  // MARK: - Browse Options Raw Values
  static nonisolated var seriesBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "seriesBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "seriesBrowseOptions") }
  }

  static nonisolated var bookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "bookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "bookBrowseOptions") }
  }

  static nonisolated var collectionSeriesBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "collectionSeriesBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "collectionSeriesBrowseOptions") }
  }

  static nonisolated var readListBookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "readListBookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "readListBookBrowseOptions") }
  }

  static nonisolated var seriesBookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "seriesBookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "seriesBookBrowseOptions") }
  }

  static nonisolated var coverOnlyCards: Bool {
    get {
      if UserDefaults.standard.object(forKey: "coverOnlyCards") != nil {
        return UserDefaults.standard.bool(forKey: "coverOnlyCards")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "coverOnlyCards")
    }
  }

  static nonisolated var showBookCardSeriesTitle: Bool {
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

  static nonisolated var thumbnailPreserveAspectRatio: Bool {
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

  static nonisolated var privacyProtection: Bool {
    get {
      UserDefaults.standard.bool(forKey: "privacyProtection")
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "privacyProtection")
    }
  }

  static nonisolated var searchIgnoreFilters: Bool {
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
  static nonisolated var showTapZoneHints: Bool {
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

  static nonisolated var tapZoneMode: TapZoneMode {
    get {
      if let stored = UserDefaults.standard.string(forKey: "tapZoneMode"),
        let mode = TapZoneMode(rawValue: stored)
      {
        return mode
      }
      return .auto
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "tapZoneMode")
    }
  }

  static nonisolated var tapZoneSize: TapZoneSize {
    get {
      if let stored = UserDefaults.standard.string(forKey: "tapZoneSize"),
        let size = TapZoneSize(rawValue: stored)
      {
        return size
      }
      return .large
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "tapZoneSize")
    }
  }

  static nonisolated var showKeyboardHelpOverlay: Bool {
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

  static nonisolated var autoFullscreenOnOpen: Bool {
    get {
      if UserDefaults.standard.object(forKey: "autoFullscreenOnOpen") != nil {
        return UserDefaults.standard.bool(forKey: "autoFullscreenOnOpen")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "autoFullscreenOnOpen")
    }
  }

  static nonisolated var readerBackground: ReaderBackground {
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

  static nonisolated var pageLayout: PageLayout {
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

  static nonisolated var forceDefaultReadingDirection: Bool {
    get {
      if UserDefaults.standard.object(forKey: "forceDefaultReadingDirection") != nil {
        return UserDefaults.standard.bool(forKey: "forceDefaultReadingDirection")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "forceDefaultReadingDirection")
    }
  }

  static nonisolated var defaultReadingDirection: ReadingDirection {
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

  static nonisolated var webtoonPageWidthPercentage: Double {
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

  static nonisolated var webtoonTapScrollPercentage: Double {
    get {
      if UserDefaults.standard.object(forKey: "webtoonTapScrollPercentage") != nil {
        return UserDefaults.standard.double(forKey: "webtoonTapScrollPercentage")
      }
      return 80.0
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "webtoonTapScrollPercentage")
    }
  }

  static nonisolated var showPageNumber: Bool {
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

  static nonisolated var tapPageTransitionDuration: Double {
    get {
      if UserDefaults.standard.object(forKey: "tapPageTransitionDuration") != nil {
        return UserDefaults.standard.double(forKey: "tapPageTransitionDuration")
      }
      return 0.2
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "tapPageTransitionDuration")
    }
  }

  static nonisolated var scrollPageTransitionStyle: ScrollPageTransitionStyle {
    get {
      if let stored = UserDefaults.standard.string(forKey: "scrollPageTransitionStyle"),
        let style = ScrollPageTransitionStyle(rawValue: stored)
      {
        return style
      }
      return .default
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "scrollPageTransitionStyle")
    }
  }

  static nonisolated var doubleTapZoomScale: Double {
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

  static nonisolated var enableLiveText: Bool {
    get {
      if UserDefaults.standard.object(forKey: "enableLiveText") != nil {
        return UserDefaults.standard.bool(forKey: "enableLiveText")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "enableLiveText")
    }
  }

  static nonisolated var shakeToOpenLiveText: Bool {
    get {
      if UserDefaults.standard.object(forKey: "shakeToOpenLiveText") != nil {
        return UserDefaults.standard.bool(forKey: "shakeToOpenLiveText")
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "shakeToOpenLiveText")
    }
  }

  // MARK: - Dashboard
  static nonisolated var dashboard: DashboardConfiguration {
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

  static nonisolated var dashboardSectionCache: DashboardSectionCache {
    get {
      if let stored = UserDefaults.standard.string(forKey: "dashboardSectionCache"),
        let cache = DashboardSectionCache(rawValue: stored)
      {
        return cache
      }
      return DashboardSectionCache()
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: "dashboardSectionCache")
    }
  }

  // MARK: - Clear all auth data
  static func clearAuthData() {
    var new = current
    new.reset()
    current = new

    serverLastUpdate = nil
    dashboard.libraryIds = []
    DashboardSectionCacheStore.shared.reset()
  }
}
