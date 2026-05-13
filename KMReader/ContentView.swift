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

          // Wire automatic recovery from auto-entered offline mode. The
          // primary mechanism is `OfflineRecoveryService`'s backoff probe
          // loop, which runs while in auto-offline mode and probes the
          // configured server periodically. `NWPathMonitor` is used as an
          // opportunistic wake-up signal (skip the current backoff when the
          // device network state changes) — it cannot serve as the primary
          // trigger because the device network is typically still satisfied
          // during a server-side outage.
          //
          // All three are idempotent: re-fires on login state changes simply
          // replace the closures and (re)start the loop where applicable.
          OfflineRecoveryService.shared.probe = {
            await attemptAutoOfflineRecovery()
          }
          NetworkPathMonitorService.shared.onPathBecameSatisfied = {
            guard AppConfig.isOffline, AppConfig.offlineWasAutomatic else { return }
            OfflineRecoveryService.shared.startOrWake()
          }
          NetworkPathMonitorService.shared.start()

          // If we are already in auto-offline at the time the user logs in
          // (e.g., bootstrap probe just failed, or migration classified a
          // persisted offline state as auto), begin the recovery loop now so
          // we are not waiting on a network or scene transition to trigger it.
          if AppConfig.isOffline, AppConfig.offlineWasAutomatic {
            OfflineRecoveryService.shared.startOrWake()
          }
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
            // Loop may still be running if the exit was driven by a non-probe
            // path (login flow, manual reconnect). Stop it explicitly so no
            // further wake-ups can spawn a stray probe.
            OfflineRecoveryService.shared.stop()
          }
          if !oldValue && newValue && AppConfig.offlineWasAutomatic {
            // Just entered auto-offline (e.g., `APIClient.handleNetworkError`
            // fired). Begin the recovery probe loop so we are not waiting on
            // an external trigger to start probing the server.
            OfflineRecoveryService.shared.startOrWake()
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            withAnimation(.easeInOut(duration: 0.2)) {
              showPrivacyBlur = false
            }
            // Wake the recovery loop if we're in auto-offline. Catches the
            // case where the loop's `Task.sleep` was deferred by iOS while
            // the app was suspended, or where a path-monitor transition fired
            // during suspension and was missed.
            if AppConfig.isOffline, AppConfig.offlineWasAutomatic {
              OfflineRecoveryService.shared.startOrWake()
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

  /// Probe the configured Komga server and exit offline mode on success, but
  /// only when we are in auto-entered offline mode. Manually-entered offline
  /// mode is preserved (the user explicitly opted in; only an explicit user
  /// action exits it).
  ///
  /// Invoked as the probe closure for `OfflineRecoveryService`, which calls
  /// it from a backoff loop while we are in auto-offline mode and also wakes
  /// it on `NWPathMonitor` path-satisfied signals and `scenePhase == .active`.
  ///
  /// Returns `true` iff this call transitioned the app from offline → online
  /// (so the recovery loop can exit). Returning `false` means the probe was
  /// skipped (no longer eligible — e.g., user manually went offline mid-loop)
  /// or the server is still unreachable.
  ///
  /// On successful exit, mirrors what `DashboardView.tryReconnect` does so
  /// the auto and manual recovery paths converge on identical post-recovery
  /// state.
  private func attemptAutoOfflineRecovery() async -> Bool {
    guard isLoggedIn else { return false }
    guard AppConfig.isOffline, AppConfig.offlineWasAutomatic else { return false }

    let reachable = await authViewModel.loadCurrentUser()

    // Re-check before mutating state:
    // - `loadCurrentUser` returns `true` even on `.unauthorized` (it calls
    //   `logout()` and returns `true` to signal "server reachable, just not
    //   authorized"). We must not treat that as a successful recovery —
    //   otherwise we'd fire a misleading "connection restored" notification
    //   while the user has actually been logged out. Re-checking `isLoggedIn`
    //   here is the guard.
    // - `AppConfig.isOffline` may have flipped false in a brief window of
    //   concurrent probes (when `OfflineRecoveryService.startOrWake` cancels
    //   and restarts the task, the previous probe may still be in flight).
    //   Re-checking ensures only one of them fires the user-visible side
    //   effects (notification, SSE reconnect).
    guard reachable, AppConfig.isLoggedIn, AppConfig.isOffline else { return false }

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
    return true
  }
}
