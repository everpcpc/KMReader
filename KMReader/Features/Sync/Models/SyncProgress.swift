//
// SyncProgress.swift
//
//

import Foundation

nonisolated struct SyncProgress: Sendable {
  let phase: SyncPhase
  let phaseProgress: Double
  let stage: SyncStage?
}

typealias SyncProgressHandler = @MainActor @Sendable (SyncProgress) -> Void
