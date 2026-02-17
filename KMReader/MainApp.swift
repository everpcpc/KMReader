//
//  KomgaApp.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

#if !os(tvOS)
  import CoreSpotlight
#endif

#if os(iOS)
  /// Scene delegate to handle Quick Actions on warm launch
  class ShortcutSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
      _ windowScene: UIWindowScene,
      performActionFor shortcutItem: UIApplicationShortcutItem,
      completionHandler: @escaping (Bool) -> Void
    ) {
      QuickActionService.handleShortcut(shortcutItem)
      completionHandler(true)
    }
  }

  /// App delegate to handle background URLSession events and Quick Actions
  class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      handleEventsForBackgroundURLSession identifier: String,
      completionHandler: @escaping () -> Void
    ) {
      BackgroundDownloadManager.shared.backgroundCompletionHandler = completionHandler
      BackgroundDownloadManager.shared.reconnectSession()
    }

    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      if let shortcutItem = options.shortcutItem {
        QuickActionService.handleShortcut(shortcutItem)
      }
      let config = UISceneConfiguration(
        name: nil, sessionRole: connectingSceneSession.role)
      config.delegateClass = ShortcutSceneDelegate.self
      return config
    }
  }
#endif

@main
struct MainApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  #endif
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif

  private let modelContainer: ModelContainer
  @State private var authViewModel: AuthViewModel
  @State private var readerPresentation = ReaderPresentationManager()
  @State private var dashboardSectionCacheStore = DashboardSectionCacheStore.shared
  @State private var deepLinkRouter = DeepLinkRouter.shared

  init() {
    let schema = Schema([
      KomgaInstance.self,
      KomgaLibrary.self,
      KomgaSeries.self,
      KomgaBook.self,
      KomgaCollection.self,
      KomgaReadList.self,
      CustomFont.self,
      PendingProgress.self,
      SavedFilter.self,
      EpubThemePreset.self,
    ])

    do {
      let configuration = ModelConfiguration(schema: schema)
      modelContainer = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      let errorMessage = String(describing: error)
      AppLogger(.database).error("Failed to create ModelContainer: \(errorMessage)")
      fatalError("Failed to create ModelContainer: \(errorMessage)")
    }

    CustomFontStore.shared.configure(with: modelContainer)
    DatabaseOperator.shared = DatabaseOperator(modelContainer: modelContainer)
    #if os(iOS)
      Task { @MainActor in
        QuickActionService.handlePendingShortcutIfNeeded()
      }
    #endif
    _ = OfflineManager.shared
    PlatformHelper.setup()
    _authViewModel = State(initialValue: AuthViewModel())
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          deepLinkRouter.handle(url: url)
        }
        #if !os(tvOS)
          .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
              if let deepLink = SpotlightIndexService.deepLink(for: identifier) {
                deepLinkRouter.pendingDeepLink = deepLink
              }
            }
          }
        #endif
        #if os(macOS)
          .background(
            MacReaderWindowConfigurator(openWindow: {
              openWindow(id: "reader")
            })
          )
          .overlay(alignment: .bottom) {
            NotificationOverlay()
          }
        #endif
        #if os(iOS)
          .tint(themeColor.color)
          .accentColor(themeColor.color)
        #endif
        .environment(authViewModel)
        .environment(readerPresentation)
        .environment(dashboardSectionCacheStore)
        .environment(deepLinkRouter)
        .modelContainer(modelContainer)
        .preferredColorScheme(appColorScheme.colorScheme)
    }
    #if os(macOS)
      WindowGroup(id: "reader") {
        ReaderWindowView()
          .environment(authViewModel)
          .environment(readerPresentation)
          .modelContainer(modelContainer)
          .preferredColorScheme(appColorScheme.colorScheme)
      }
      .windowToolbarStyle(.unifiedCompact)
      .defaultSize(width: 1200, height: 800)

      Settings {
        SettingsView_macOS()
          .environment(authViewModel)
          .modelContainer(modelContainer)
          .preferredColorScheme(appColorScheme.colorScheme)
      }
      .windowToolbarStyle(.unifiedCompact)
      .defaultSize(width: 800, height: 600)
    #endif
  }
}
