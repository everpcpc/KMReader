//
// AppBootstrapper.swift
//
//

import Foundation

@MainActor
@Observable
final class AppBootstrapper {
  static let shared = AppBootstrapper()

  private(set) var isBootstrapping = true
  private(set) var progress = 0.0
  private(set) var phaseName = String(localized: "splash.loading.preparing")

  private var hasStarted = false
  private let logger = AppLogger(.database)

  private init() {}

  func startIfNeeded() {
    guard !hasStarted else { return }
    hasStarted = true

    Task.detached(priority: .userInitiated) {
      AppSQLiteBootstrap.bootstrap { update in
        Task { @MainActor in
          AppBootstrapper.shared.update(update)
        }
      }

      await MainActor.run {
        DatabaseOperator.shared = DatabaseOperator()
        #if os(iOS)
          QuickActionService.handlePendingShortcutIfNeeded()
        #endif
        AppBootstrapper.shared.complete()
      }
    }
  }

  private func update(_ update: AppSQLiteBootstrap.ProgressUpdate) {
    progress = min(max(update.fractionComplete, 0.0), 1.0)
    phaseName =
      switch update.phase {
      case .preparing:
        String(localized: "splash.loading.preparing")
      case .importing:
        String(localized: "splash.loading.syncing")
      case .finalizing:
        String(localized: "splash.loading.updating")
      }
  }

  private func complete() {
    progress = 1.0
    phaseName = String(localized: "splash.loading.updating")
    isBootstrapping = false
    logger.info("App bootstrap completed")
  }
}
