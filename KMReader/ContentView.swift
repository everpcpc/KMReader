//
// ContentView.swift
//
//

import SwiftData
import SwiftUI

struct ContentView: View {
  let authViewModel: AuthViewModel
  let readerPresentation: ReaderPresentationManager
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage("isLoggedInV2") private var isLoggedIn: Bool = false
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("privacyProtection") private var privacyProtection: Bool = false

  @State private var showPrivacyBlur = false

  #if os(iOS) || os(tvOS)
    @Namespace private var zoomNamespace
  #endif

  private var instanceInitializer: InstanceInitializer {
    InstanceInitializer.shared
  }

  private var context: AppViewContext {
    AppViewContext(
      authViewModel: authViewModel,
      readerPresentation: readerPresentation
    )
  }

  private var isReady: Bool {
    (authViewModel.bootstrapState == .ready || isOffline) && !instanceInitializer.isSyncing
  }

  private var automaticReadingHistorySyncTrigger: String {
    guard isLoggedIn, authViewModel.bootstrapState == .ready, !isOffline, !current.instanceId.isEmpty
    else {
      return ""
    }
    return current.instanceId
  }

  var body: some View {
    Group {
      if isLoggedIn {
        Group {
          if isReady {
            #if os(macOS)
              MainSplitView(context: context)
            #elseif os(iOS)
              if PlatformHelper.isPad {
                MainSplitView(context: context)
              } else {
                if #available(iOS 18.0, *) {
                  PhoneTabView(context: context)
                } else {
                  OldTabView(context: context)
                }
              }
            #elseif os(tvOS)
              if #available(tvOS 18.0, *) {
                TVTabView(context: context)
              } else {
                OldTabView(context: context)
              }
            #endif
          } else {
            SplashView(initializer: instanceInitializer) {
              isOffline = true
            }
          }
        }
        .task(id: isLoggedIn) {
          guard isLoggedIn else { return }

          if authViewModel.bootstrapState == .requiresValidation {
            let serverReachable = await authViewModel.loadCurrentUser()
            isOffline = !serverReachable
          }

          guard isLoggedIn else { return }

          if enableSSE && !isOffline {
            await SSEService.shared.connect()
          }
          WidgetDataService.refreshWidgetData()
        }
        .task(id: automaticReadingHistorySyncTrigger) {
          guard !automaticReadingHistorySyncTrigger.isEmpty else { return }
          await instanceInitializer.syncReadingProgressOnly()
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
              if let database = await DatabaseOperator.databaseIfConfigured() {
                await database.updateInstanceLastUsed(instanceId: AppConfig.current.instanceId)
              }
              // Resume offline downloads if not paused and online
              if !AppConfig.isOffline && !AppConfig.offlinePaused {
                OfflineManager.shared.triggerSync(
                  instanceId: AppConfig.current.instanceId, restart: true)
              }
              await instanceInitializer.syncReadingProgressOnly()
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
            Task(priority: .utility) {
              await SSEService.shared.disconnect(notify: false)
              if let database = await DatabaseOperator.databaseIfConfigured() {
                try? await database.commitImmediately()
              }
            }
            WidgetDataService.refreshWidgetData()
          }
        }
      } else {
        LandingView(authViewModel: authViewModel)
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
        ReaderOverlay(namespace: zoomNamespace, readerPresentation: readerPresentation)
      }
    #endif
    #if os(iOS) || os(tvOS)
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
