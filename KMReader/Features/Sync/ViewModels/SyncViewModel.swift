//
// SyncViewModel.swift
//
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SyncViewModel {
  static let shared = SyncViewModel()

  private(set) var isSyncing = false
  private var isSyncingReadingProgress = false
  private(set) var progress = 0.0
  private(set) var currentPhase: SyncPhase = .libraries
  private(set) var phaseProgress = SyncPhase.initialProgress
  private(set) var stageProgress = SyncStage.initialProgress
  private(set) var visibleStages = SyncStage.visibleStages(includeReconcile: false)
  private(set) var includesReconcileStages = false

  private let worker = SyncWorker()

  private init() {}

  var currentPhaseName: String {
    currentPhase.localizedName
  }

  func progress(for phase: SyncPhase) -> Double {
    phaseProgress[phase] ?? 0.0
  }

  func progress(for stage: SyncStage) -> Double {
    stageProgress[stage] ?? 0.0
  }

  func syncData(forceFullSync: Bool = false) async {
    guard !isSyncing, !isSyncingReadingProgress else { return }
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }

    isSyncing = true
    progress = 0.0
    phaseProgress = SyncPhase.initialProgress
    stageProgress = SyncStage.initialProgress
    includesReconcileStages = forceFullSync
    visibleStages = SyncStage.visibleStages(includeReconcile: forceFullSync)
    defer { isSyncing = false }

    let result = await worker.sync(
      request: SyncRequest(
        instanceId: instanceId,
        forceFullSync: forceFullSync
      )
    ) { [weak self] progress in
      self?.apply(progress)
    }

    if result.readingProgressSynced {
      AppConfig.setReadingProgressSyncTime(Date(), instanceId: instanceId)
    }

    progress = 1.0
    ErrorManager.shared.notify(
      message: result.hasFailures
        ? String(localized: "notification.offline.syncCompletedWithIssues")
        : String(localized: "notification.offline.syncCompleted")
    )
  }

  func syncReadingProgressOnly(force: Bool = false) async {
    guard !isSyncing, !isSyncingReadingProgress else { return }
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }
    guard force || !AppConfig.isOffline else { return }
    guard force || !shouldSkipReadingProgressSync(instanceId: instanceId) else { return }

    isSyncingReadingProgress = true
    defer { isSyncingReadingProgress = false }

    let syncSucceeded = await worker.syncReadingProgress(instanceId: instanceId)
    guard syncSucceeded else { return }

    AppConfig.setReadingProgressSyncTime(Date(), instanceId: instanceId)
    ErrorManager.shared.notify(
      message: String(
        localized: "notification.offline.readHistorySyncCompleted",
        defaultValue: "Reading history sync completed"
      )
    )
  }

  private func shouldSkipReadingProgressSync(instanceId: String) -> Bool {
    guard let interval = AppConfig.readingHistoryAutoSyncMinimumInterval else {
      return true
    }
    guard let lastSyncTime = AppConfig.readingProgressSyncTime(instanceId: instanceId) else {
      return false
    }
    return Date().timeIntervalSince(lastSyncTime) < interval
  }

  private func apply(_ syncProgress: SyncProgress) {
    currentPhase = syncProgress.phase
    updateProgress(
      phase: syncProgress.phase,
      phaseProgress: syncProgress.phaseProgress,
      stage: syncProgress.stage
    )
  }

  private func updateProgress(
    phase: SyncPhase,
    phaseProgress: Double,
    stage: SyncStage? = nil
  ) {
    let clampedPhaseProgress = min(max(phaseProgress, 0.0), 1.0)
    let effectivePhaseProgress = updateStageProgress(
      phase: phase,
      phaseProgress: clampedPhaseProgress,
      stage: stage
    )
    self.phaseProgress[phase] = effectivePhaseProgress
    let phaseOffset = phase.progressOffset
    let phaseContribution = (phase.weight / SyncPhase.totalWeight) * effectivePhaseProgress
    progress = phaseOffset + phaseContribution
  }

  private func updateStageProgress(
    phase: SyncPhase,
    phaseProgress: Double,
    stage: SyncStage?
  ) -> Double {
    switch phase {
    case .libraries:
      stageProgress[.libraries] = phaseProgress
      return phaseProgress
    case .collections:
      stageProgress[.collections] = phaseProgress
      return phaseProgress
    case .readLists:
      stageProgress[.readLists] = phaseProgress
      return phaseProgress
    case .series:
      return updateSplitStageProgress(
        incrementalStage: .seriesIncremental,
        reconcileStage: .seriesReconcile,
        phaseProgress: phaseProgress,
        stage: stage
      )
    case .books:
      return updateSplitStageProgress(
        incrementalStage: .booksIncremental,
        reconcileStage: .booksReconcile,
        phaseProgress: phaseProgress,
        stage: stage
      )
    }
  }

  private func updateSplitStageProgress(
    incrementalStage: SyncStage,
    reconcileStage: SyncStage,
    phaseProgress: Double,
    stage: SyncStage?
  ) -> Double {
    guard includesReconcileStages else {
      stageProgress[incrementalStage] = phaseProgress
      stageProgress[reconcileStage] = 0.0
      return phaseProgress
    }

    if stage == incrementalStage {
      stageProgress[incrementalStage] = phaseProgress
    } else if stage == reconcileStage {
      stageProgress[reconcileStage] = phaseProgress
    }

    let incrementalProgress = stageProgress[incrementalStage] ?? 0.0
    let reconcileProgress = stageProgress[reconcileStage] ?? 0.0
    return (incrementalProgress + reconcileProgress) / 2.0
  }
}
