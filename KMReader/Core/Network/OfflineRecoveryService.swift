//
// OfflineRecoveryService.swift
//
//

import Foundation

/// Drives the recovery probe loop that runs while the app is in auto-entered
/// offline mode. Periodically invokes a consumer-provided `probe` closure with
/// exponential backoff between attempts; exits when the probe reports a
/// successful recovery.
///
/// Why a probe loop instead of relying on `NWPathMonitor` alone: in KMReader
/// "offline mode" means "the configured Komga server is unreachable," not
/// "the device has no network." The device's network path is frequently
/// satisfied during a server-side hiccup (NAS rebooting, reverse proxy down,
/// VPN flap, DNS dropout), so a pure `NWPathMonitor` trigger would never fire
/// and the app would stay stuck in auto-offline indefinitely. `NWPathMonitor`
/// is still useful as a wake-up signal (call `startOrWake` to skip the current
/// backoff and probe immediately) but the loop is the workhorse.
///
/// Backoff: 5s → 10s → 20s → 40s → 80s → 160s → 300s (capped at 5 minutes).
/// Capped because indefinite doubling would push retry intervals to hours,
/// well beyond a reasonable expectation of how long a server outage lasts
/// before the user notices and intervenes manually. 5 minutes is a balance
/// between not hammering the server and recovering promptly once it's back.
@MainActor
final class OfflineRecoveryService {
  static let shared = OfflineRecoveryService()

  /// Closure that performs one server probe attempt. Returns `true` if the
  /// probe transitioned the app from offline → online as a result (i.e., the
  /// loop should stop). Returning `false` means the probe was either skipped
  /// (no longer eligible) or the server is still unreachable; the loop will
  /// sleep with backoff and retry.
  ///
  /// The consumer is responsible for performing all post-recovery work (e.g.,
  /// calling `AppConfig.exitOfflineMode`, reconnecting SSE, notifying the
  /// user) within the probe before returning `true`.
  var probe: (() async -> Bool)?

  private var task: Task<Void, Never>?
  private let logger = AppLogger(.api)

  private init() {}

  /// Begin or wake the recovery probe loop. Idempotent in that it can be
  /// called any number of times: each call cancels any in-flight task and
  /// starts a fresh one with backoff reset to the minimum. Used as both the
  /// initial start (when transitioning into auto-offline mode) and as a
  /// wake-up signal (from `NWPathMonitor` or `scenePhase == .active`) to skip
  /// the current backoff sleep.
  ///
  /// A brief window of concurrent probes may exist between the cancellation
  /// of the previous task and the next iteration of its loop noticing the
  /// cancellation. The probe closure is expected to guard against this
  /// (e.g., re-checking `AppConfig.isOffline` before flipping state and
  /// firing user-visible notifications).
  func startOrWake() {
    task?.cancel()
    task = Task { [weak self] in
      await self?.runLoop()
    }
  }

  /// Cancel the recovery loop. Used when the app exits auto-offline mode by
  /// any path (probe success, manual reconnect, login, transition to manual
  /// offline mode). Safe to call when no loop is running.
  func stop() {
    task?.cancel()
    task = nil
  }

  private func runLoop() async {
    var backoffSeconds: UInt64 = 5
    logger.debug("🔁 [OfflineRecovery] Loop started")
    defer { logger.debug("🔁 [OfflineRecovery] Loop ended") }

    while !Task.isCancelled {
      let recovered = await (probe?() ?? false)
      if recovered {
        logger.info("✅ [OfflineRecovery] Probe succeeded; exiting loop")
        return
      }

      logger.debug(
        "⏳ [OfflineRecovery] Probe failed; sleeping \(backoffSeconds)s before retry"
      )
      try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
      if Task.isCancelled { return }
      backoffSeconds = min(backoffSeconds * 2, 300)
    }
  }
}
