//
// MainApp.swift
//
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

  @State private var modelContainer: ModelContainer?
  @State private var isPreparingModelContainer = false
  @State private var modelContainerFailureDetails: String?
  @State private var authViewModel: AuthViewModel
  @State private var readerPresentation = ReaderPresentationManager()
  @State private var dashboardSectionCacheStore = DashboardSectionCacheStore.shared
  @State private var deepLinkRouter = DeepLinkRouter.shared

  init() {
    PlatformHelper.setup()
    _authViewModel = State(initialValue: AuthViewModel())
  }

  private func makeModelContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: KMReaderSchemaV3.self)
    let configuration = ModelConfiguration(schema: schema)
    return try ModelContainer(
      for: schema,
      migrationPlan: KMReaderMigrationPlan.self,
      configurations: [configuration]
    )
  }

  @MainActor
  private func prepareModelContainerIfNeeded(forceRetry: Bool = false) async {
    guard modelContainer == nil, !isPreparingModelContainer else { return }
    isPreparingModelContainer = true
    defer { isPreparingModelContainer = false }
    if forceRetry {
      modelContainerFailureDetails = nil
    }

    do {
      let container = try makeModelContainer()
      CustomFontStore.shared.configure(with: container)
      DatabaseOperator.shared = DatabaseOperator(modelContainer: container)
      _ = OfflineManager.shared
      modelContainer = container
      #if os(iOS)
        QuickActionService.handlePendingShortcutIfNeeded()
      #endif
      modelContainerFailureDetails = nil
    } catch {
      let errorMessage = String(describing: error)
      AppLogger(.database).error("Failed to create ModelContainer: \(errorMessage)")
      modelContainerFailureDetails = errorMessage
    }
  }

  @ViewBuilder
  private func modelContainerGate<Content: View>(
    @ViewBuilder content: (ModelContainer) -> Content
  ) -> some View {
    if let modelContainer {
      content(modelContainer)
    } else if let modelContainerFailureDetails {
      StartupFailureView(
        details: modelContainerFailureDetails,
        onRetry: {
          Task {
            await prepareModelContainerIfNeeded(forceRetry: true)
          }
        }
      )
    } else {
      SplashView(isMigration: true)
        .task {
          await prepareModelContainerIfNeeded()
        }
    }
  }

  @ViewBuilder
  private func mainWindowContent(modelContainer: ModelContainer) -> some View {
    ContentView()
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
      .modelContainer(modelContainer)
  }

  var body: some Scene {
    WindowGroup {
      modelContainerGate { modelContainer in
        mainWindowContent(modelContainer: modelContainer)
      }
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
      #if os(iOS)
        .tint(themeColor.color)
        .accentColor(themeColor.color)
      #endif
      .environment(authViewModel)
      .environment(readerPresentation)
      .environment(dashboardSectionCacheStore)
      .environment(deepLinkRouter)
      .preferredColorScheme(appColorScheme.colorScheme)
    }
    #if os(macOS)
      WindowGroup(id: "reader") {
        modelContainerGate { modelContainer in
          ReaderWindowView()
            .environment(authViewModel)
            .environment(readerPresentation)
            .modelContainer(modelContainer)
        }
        .preferredColorScheme(appColorScheme.colorScheme)
      }
      .windowToolbarStyle(.unifiedCompact)
      .defaultSize(width: 1200, height: 800)

      Settings {
        modelContainerGate { modelContainer in
          SettingsView_macOS()
            .environment(authViewModel)
            .modelContainer(modelContainer)
        }
        .preferredColorScheme(appColorScheme.colorScheme)
      }
      .windowToolbarStyle(.unifiedCompact)
      .defaultSize(width: 800, height: 600)
    #endif
  }
}
