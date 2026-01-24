//
//  KomgaApp.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

#if os(iOS)
  /// App delegate to handle background URLSession events
  class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      handleEventsForBackgroundURLSession identifier: String,
      completionHandler: @escaping () -> Void
    ) {
      BackgroundDownloadManager.shared.backgroundCompletionHandler = completionHandler
      BackgroundDownloadManager.shared.reconnectSession()
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

  init() {
    do {
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

      let configuration = ModelConfiguration(schema: schema)
      modelContainer = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
    CustomFontStore.shared.configure(with: modelContainer)
    DatabaseOperator.shared = DatabaseOperator(modelContainer: modelContainer)
    _ = OfflineManager.shared
    PlatformHelper.setup()
    _authViewModel = State(initialValue: AuthViewModel())
  }

  var body: some Scene {
    WindowGroup {
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
        #if os(iOS)
          .tint(themeColor.color)
          .accentColor(themeColor.color)
        #endif
        .environment(authViewModel)
        .environment(readerPresentation)
        .environment(dashboardSectionCacheStore)
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
