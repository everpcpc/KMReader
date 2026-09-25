//
// RefreshableMinimumHold.swift
//
//

import SwiftUI

/// Holds the refresh control up for at least this long, so a fast reload
/// (e.g. a local-database query) doesn't snap back instantly.
private let minimumRefreshHoldDuration: Duration = .milliseconds(800)

extension View {
  /// `.refreshable` whose control stays visible for a minimum total time;
  /// the awaited reload still gates dismissal when it runs longer.
  func refreshableWithMinimumHold(
    _ action: @escaping @Sendable () async -> Void
  ) -> some View {
    refreshable {
      let startedAt = ContinuousClock.now
      await action()
      let remaining = minimumRefreshHoldDuration - (ContinuousClock.now - startedAt)
      if remaining > .zero {
        try? await Task.sleep(for: remaining)
      }
    }
  }
}
