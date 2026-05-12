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
              AppConfig.enterAutoOfflineMode()
            }
          }
        }
        .task(id: isLoggedIn) {
          guard isLoggedIn else { return }

          if authViewModel.bootstrapState == .requiresValidation {
            let serverReachable = await authViewModel.loadCurrentUser()
            if serverReachable {
              AppConfig.exitOfflineMode()
            } else {
              // No-op if we were already in manual offline mode (`enterAutoOfflineMode`
              // is guarded against converting manual → auto).
              AppConfig.enterAutoOfflineMode()
            }
          }

          guard isLoggedIn else { return }

          if enableSSE && !isOffline {
            await SSEService.shared.connect()
          }
          WidgetDataService.refreshWidgetData()

          // Wire automatic recovery from auto-entered offline mode. Idempotent —
          // re-fires on login state changes are safe (start is guarded; callback
          // re-assignment replaces the previous closure with one capturing the
          // current view state, which is what we want after a server switch).
          NetworkPathMonitorService.shared.onPathBecameSatisfied = {
            await attemptAutoOfflineRecovery()
          }
          NetworkPathMonitorService.shared.start()
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
              // Run recovery probe first: if the path-monitor signal was missed
              // while the app was suspended, this is the catch-up. Successful
              // probe exits offline mode before the subsequent gated work runs.
              await attemptAutoOfflineRecovery()

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

  /// Probe the server and exit offline mode on success, but only when we are
  /// in auto-entered offline mode. Manually-entered offline mode is preserved
  /// (the user explicitly opted in; only an explicit user action exits it).
  ///
  /// Invoked from two triggers:
  /// 1. `NetworkPathMonitorService` callback — fires when the OS detects the
  ///    network path transitioned from unsatisfied → satisfied.
  /// 2. `scenePhase == .active` — catches recoveries the path-monitor may have
  ///    missed while the app was suspended in the background.
  ///
  /// On successful exit, mirrors what `DashboardView.tryReconnect` does so the
  /// auto and manual recovery paths converge on identical post-recovery state.
  private func attemptAutoOfflineRecovery() async {
    guard isLoggedIn else { return }
    guard AppConfig.isOffline, AppConfig.offlineWasAutomatic else { return }

    let reachable = await authViewModel.loadCurrentUser()
    guard reachable else { return }

    AppConfig.exitOfflineMode()
    if enableSSE {
      await SSEService.shared.connect()
    }
    ErrorManager.shared.notify(
      message: String(localized: "settings.connection_restored")
    )
    // `ContentView.onChange(of: isOffline)` handles `syncPendingProgress` and
    // `triggerSync` for offline downloads once the flag transitions back to
    // online; nothing else to do here.
  }
}
