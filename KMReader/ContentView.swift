//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false

  #if os(iOS) || os(tvOS)
    @Namespace private var zoomNamespace
    @Environment(ReaderPresentationManager.self) private var readerPresentation
  #endif

  private var instanceInitializer: InstanceInitializer {
    InstanceInitializer.shared
  }

  private var isReady: Bool {
    (authViewModel.user != nil || isOffline) && !instanceInitializer.isSyncing
  }

  var body: some View {
    Group {
      if isLoggedIn {
        Group {
          if isReady {
            #if os(macOS)
              MainSplitView()
            #elseif os(iOS)
              if PlatformHelper.isPad {
                MainSplitView()
              } else {
                if #available(iOS 18.0, *) {
                  PhoneTabView()
                } else {
                  OldTabView()
                }
              }
            #elseif os(tvOS)
              if #available(tvOS 18.0, *) {
                TVTabView()
              } else {
                OldTabView()
              }
            #endif
          } else {
            SplashView(initializer: instanceInitializer)
          }
        }
        .task {
          let serverReachable = await authViewModel.loadCurrentUser(timeout: 5)
          isOffline = !serverReachable
          if enableSSE && serverReachable {
            SSEService.shared.connect()
          }
        }
        .onChange(of: isOffline) { oldValue, newValue in
          if oldValue && !newValue {
            // Just came back online - sync pending progress and resume downloads
            Task {
              await ProgressSyncService.shared.syncPendingProgress(
                instanceId: AppConfig.currentInstanceId
              )
              // Resume offline downloads
              if !AppConfig.offlinePaused {
                OfflineManager.shared.triggerSync(
                  instanceId: AppConfig.currentInstanceId, restart: true)
              }
            }
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task {
              await DatabaseOperator.shared.updateInstanceLastUsed(
                instanceId: AppConfig.currentInstanceId)
              // Resume offline downloads if not paused and online
              if !AppConfig.isOffline && !AppConfig.offlinePaused {
                OfflineManager.shared.triggerSync(
                  instanceId: AppConfig.currentInstanceId, restart: true)
              }
            }
          }
        }
      } else {
        LandingView()
          .onAppear {
            SSEService.shared.disconnect()
          }
      }
    }
    #if os(iOS) || os(tvOS)
      .environment(\.zoomNamespace, zoomNamespace)
      .overlay {
        ReaderOverlay(namespace: zoomNamespace)
      }
      .setupNotificationWindow()
    #endif
  }
}

struct OldTabView: View {
  @State private var selectedTab: TabItem = .home

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        TabItem.home.content
          .handleNavigation()
      }
      .tabItem { TabItem.home.label }

      NavigationStack {
        TabItem.browse.content
          .handleNavigation()
      }
      .tabItem { TabItem.browse.label }

      NavigationStack {
        TabItem.settings.content
          .handleNavigation()
      }
      .tabItem { TabItem.settings.label }
    }
  }
}
