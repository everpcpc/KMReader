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

  @AppStorage("isLoggedInV2") private var isLoggedIn: Bool = false
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("privacyProtection") private var privacyProtection: Bool = false

  @State private var showPrivacyBlur = false

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
          let serverReachable = await authViewModel.loadCurrentUser()
          isOffline = !serverReachable
          await SSEService.shared.connect()
        }
        .onChange(of: isOffline) { oldValue, newValue in
          if oldValue && !newValue {
            // Just came back online - sync pending progress and resume downloads
            Task {
              await ProgressSyncService.shared.syncPendingProgress(
                instanceId: AppConfig.current.instanceId
              )
              // Resume offline downloads
              if !AppConfig.offlinePaused {
                OfflineManager.shared.triggerSync(
                  instanceId: AppConfig.current.instanceId, restart: true)
              }
            }
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            withAnimation(.easeInOut(duration: 0.2)) {
              showPrivacyBlur = false
            }
            Task {
              await DatabaseOperator.shared.updateInstanceLastUsed(
                instanceId: AppConfig.current.instanceId)
              // Resume offline downloads if not paused and online
              if !AppConfig.isOffline && !AppConfig.offlinePaused {
                OfflineManager.shared.triggerSync(
                  instanceId: AppConfig.current.instanceId, restart: true)
              }
            }
            if enableSSE && !isOffline {
              Task {
                await SSEService.shared.connect()
              }
            }
          } else if phase == .inactive {
            if privacyProtection {
              showPrivacyBlur = true
            }
          } else if phase == .background {
            if privacyProtection {
              showPrivacyBlur = true
            }
            Task {
              await SSEService.shared.disconnect(notify: false)
            }
            Task.detached(priority: .utility) {
              try? await DatabaseOperator.shared.commitImmediately()
            }
          }
        }
      } else {
        LandingView()
          .onAppear {
            Task {
              await SSEService.shared.disconnect(notify: false)
            }
          }
      }
    }
    #if os(iOS) || os(tvOS)
      .environment(\.zoomNamespace, zoomNamespace)
      .overlay {
        ReaderOverlay(namespace: zoomNamespace)
      }
    #endif
    #if os(iOS)
      .setupNotificationWindow()
    #elseif os(tvOS)
      .overlay(alignment: .bottom) {
        NotificationOverlay()
      }
    #endif
    .overlay {
      if showPrivacyBlur {
        ZStack {
          Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()

          Image(systemName: "lock.fill")
            .font(.system(size: 60))
            .foregroundStyle(.secondary)
        }
        .transition(.opacity)
      }
    }
  }
}
