//
// NetworkPathMonitorService.swift
//
//

import Foundation
import Network

/// Watches the device's network reachability via `NWPathMonitor` and fires a
/// callback when the path transitions from unsatisfied → satisfied (i.e., the
/// device just regained internet connectivity).
///
/// Used to drive automatic recovery from auto-entered offline mode: when the
/// network returns, the consumer probes the server and exits offline mode on
/// success. The OS push-based notification means recovery latency is typically
/// well under a second from when the device decides it has internet again, and
/// there is no polling cost in the steady state.
///
/// The service is a singleton with a single shared `NWPathMonitor` instance.
/// Start it once at app launch via `start()`; it never stops. The initial path
/// update from `NWPathMonitor` (which reports the current state at the moment
/// the monitor begins) is suppressed so the callback only fires on actual
/// transitions, not on whatever the app's current state happens to be at boot.
@MainActor
final class NetworkPathMonitorService {
  static let shared = NetworkPathMonitorService()

  /// Callback invoked on the main actor whenever the network path transitions
  /// from any non-satisfied state to `.satisfied`. The consumer decides how to
  /// act on the signal (typically: probe the server, exit offline mode on
  /// success). The closure may be replaced any time; only the most recently
  /// assigned closure receives subsequent transitions.
  var onPathBecameSatisfied: (@MainActor () async -> Void)?

  private let monitor: NWPathMonitor
  private let monitorQueue: DispatchQueue
  private var hasStarted = false
  private var lastSatisfied = false
  private var hasReceivedFirstUpdate = false
  private let logger = AppLogger(.api)

  private init() {
    self.monitor = NWPathMonitor()
    self.monitorQueue = DispatchQueue(
      label: "com.everpcpc.kmreader.networkPathMonitor",
      qos: .utility
    )
  }

  /// Idempotent. Safe to call multiple times — subsequent calls do nothing.
  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    monitor.pathUpdateHandler = { [weak self] path in
      // NWPathMonitor calls this on its own dispatch queue; hop to MainActor
      // before touching any service state or invoking the consumer callback.
      let isSatisfied = path.status == .satisfied
      Task { @MainActor [weak self] in
        await self?.handlePathUpdate(satisfied: isSatisfied)
      }
    }
    monitor.start(queue: monitorQueue)
    logger.debug("📡 [NetworkPathMonitor] Started")
  }

  private func handlePathUpdate(satisfied: Bool) async {
    if !hasReceivedFirstUpdate {
      // Suppress the initial state report so the callback only fires on
      // genuine transitions during a session. The app's boot path already
      // probes the server explicitly (`ContentView.task(id: isLoggedIn)`),
      // and a duplicate trigger here would be wasted work.
      hasReceivedFirstUpdate = true
      lastSatisfied = satisfied
      logger.debug("📡 [NetworkPathMonitor] Initial path state: satisfied=\(satisfied)")
      return
    }

    let wasSatisfied = lastSatisfied
    lastSatisfied = satisfied

    // Only react to unsatisfied → satisfied transitions. Other path updates
    // (interface changes between two satisfied states, isExpensive toggles,
    // etc.) are not actionable for our recovery use case.
    guard !wasSatisfied, satisfied else { return }

    logger.info("📡 [NetworkPathMonitor] Path became satisfied; signaling consumer")
    await onPathBecameSatisfied?()
  }
}
