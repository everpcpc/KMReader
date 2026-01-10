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

  static var apiTimeout: Double {
    get {
      if UserDefaults.standard.object(forKey: "apiTimeout") != nil {
        return UserDefaults.standard.double(forKey: "apiTimeout")
      }
      return 10.0
    }
    set { UserDefaults.standard.set(newValue, forKey: "apiTimeout") }
  }

  static var apiRetryCount: Int {
    get {
      if UserDefaults.standard.object(forKey: "apiRetryCount") != nil {
        return UserDefaults.standard.integer(forKey: "apiRetryCount")
      }
      return 0
    }
    set { UserDefaults.standard.set(newValue, forKey: "apiRetryCount") }
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

  static var gridDensity: Double {
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

  // MARK: - Browse Options Raw Values
  static var seriesBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "seriesBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "seriesBrowseOptions") }
  }

  static var bookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "bookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "bookBrowseOptions") }
  }

  static var collectionSeriesBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "collectionSeriesBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "collectionSeriesBrowseOptions") }
  }

  static var readListBookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "readListBookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "readListBookBrowseOptions") }
  }

  static var seriesBookBrowseOptions: String {
    get { UserDefaults.standard.string(forKey: "seriesBookBrowseOptions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "seriesBookBrowseOptions") }
  }

  static var coverOnlyCards: Bool {
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

  static var tapZoneSize: TapZoneSize {
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

  static var autoFullscreenOnOpen: Bool {
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

  static var forceDefaultReadingDirection: Bool {
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

  static var webtoonTapScrollPercentage: Double {
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

  static var tapPageTransitionDuration: Double {
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

  static var scrollPageTransitionStyle: ScrollPageTransitionStyle {
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

  static var enableLiveText: Bool {
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

  static var dashboardSectionCache: DashboardSectionCache {
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
    authToken = ""
    authMethod = .basicAuth
    username = ""
    serverDisplayName = ""
    isAdmin = false
    currentInstanceId = ""
    serverLastUpdate = nil
    dashboard.libraryIds = []
    DashboardSectionCacheStore.shared.reset()
  }
}
