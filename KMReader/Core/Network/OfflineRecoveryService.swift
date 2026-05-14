//
// OfflineRecoveryService.swift
//
//

import Foundation

/// Drives the recovery probe loop that runs while the app is in auto-entered
/// offline mode. Periodically invokes a consumer-provided `probe` closure with
/// exponential backoff between attempts; exits when the probe reports a
/// successful recovery or a no-longer-eligible state.
///
/// Why a probe loop instead of relying on `NWPathMonitor` alone: in KMReader
/// "offline mode" means "the configured Komga server is unreachable," not
/// "the device has no network." The device's network path is frequently
/// satisfied during a server-side hiccup (NAS rebooting, reverse proxy down,
/// VPN flap, DNS dropout), so a pure `NWPathMonitor` trigger would never fire
/// and the app would stay stuck in auto-offline indefinitely. `NWPathMonitor`
/// is still useful as a wake-up signal (call `wakeNow` to skip the current
/// backoff and probe immediately) but the loop is the workhorse.
///
/// Backoff: 5s → 10s → 20s → 40s → 80s → 160s → 300s (capped at 5 minutes).
/// Capped because indefinite doubling would push retry intervals to hours,
/// well beyond a reasonable expectation of how long a server outage lasts
/// before the user notices and intervenes manually. 5 minutes is a balance
/// between not hammering the server and recovering promptly once it's back.
@MainActor
final class OfflineRecoveryService {
  enum ProbeResult {
    case recovered
    case retry
    case stop
  }

  static let shared = OfflineRecoveryService()

  /// Closure that performs one server probe attempt.
  ///
  /// The consumer is responsible for performing all post-recovery work (e.g.,
  /// calling `AppConfig.exitOfflineMode`, reconnecting SSE, notifying the
  /// user) within the probe before returning `.recovered`.
  var probe: (() async -> ProbeResult)?

  private var task: Task<Void, Never>?
  private var taskID: UUID?
  private var nextBackoffSeconds: UInt64 = 5
  private let logger = AppLogger(.api)

  private init() {}

  /// Begin the recovery probe loop if it is not already running. A new loop
  /// starts with the minimum backoff.
  func startIfNeeded() {
    guard task == nil else { return }
    startTask(resetBackoff: true)
  }

  /// Wake the loop by cancelling the current sleep and probing immediately,
  /// while preserving the current backoff interval. If no loop is running,
  /// starts one from the minimum backoff.
  func wakeNow() {
    guard task != nil else {
      startIfNeeded()
      return
    }
    startTask(resetBackoff: false)
  }

  /// Cancel the recovery loop. Used when the app exits auto-offline mode by
  /// any path (probe success, manual reconnect, login, transition to manual
  /// offline mode). Safe to call when no loop is running.
  func stop() {
    task?.cancel()
    task = nil
    taskID = nil
    nextBackoffSeconds = 5
  }

  private func startTask(resetBackoff: Bool) {
    task?.cancel()
    if resetBackoff {
      nextBackoffSeconds = 5
    }
    let id = UUID()
    taskID = id
    task = Task { [weak self] in
      await self?.runLoop(taskID: id)
    }
  }

  private func runLoop(taskID id: UUID) async {
    logger.debug("🔁 [OfflineRecovery] Loop started")
    defer {
      logger.debug("🔁 [OfflineRecovery] Loop ended")
      if taskID == id {
        task = nil
        taskID = nil
      }
    }

    while !Task.isCancelled {
      switch await (probe?() ?? .stop) {
      case .recovered:
        logger.info("✅ [OfflineRecovery] Probe succeeded; exiting loop")
        return
      case .stop:
        logger.debug("🔁 [OfflineRecovery] Probe no longer eligible; exiting loop")
        return
      case .retry:
        break
      }

      let sleepSeconds = nextBackoffSeconds
      logger.debug(
        "⏳ [OfflineRecovery] Probe failed; sleeping \(sleepSeconds)s before retry"
      )
      try? await Task.sleep(nanoseconds: sleepSeconds * 1_000_000_000)
      if Task.isCancelled { return }
      nextBackoffSeconds = min(sleepSeconds * 2, 300)
    }
  }
}
