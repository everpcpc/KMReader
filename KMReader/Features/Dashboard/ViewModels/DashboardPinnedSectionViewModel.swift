//
// DashboardPinnedSectionViewModel.swift
//
//

import Foundation
import SwiftUI

/// Loads one pinned dashboard row (collections or read lists): the local items
/// first, then a server sync.
///
/// Like `DashboardSectionViewModel`, the refresh runs in a task this model
/// owns, so the split view re-adding the dashboard cannot cancel the sync
/// halfway and leave the retry blocked behind the cancelled run.
@MainActor
@Observable
final class DashboardPinnedSectionViewModel {
  let section: DashboardSection

  private(set) var pinnedCollections: [CollectionDisplayItem] = []
  private(set) var pinnedReadLists: [ReadListDisplayItem] = []

  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var refreshingInstanceId: String?
  @ObservationIgnored private var refreshID = UUID()

  init(section: DashboardSection) {
    self.section = section
  }

  /// Refreshes when the row appears, joining a refresh already running for
  /// the same server.
  func refreshIfNeeded(instanceId: String) {
    guard refreshTask == nil || refreshingInstanceId != instanceId else { return }
    startRefresh(instanceId: instanceId)
  }

  /// Restarts the refresh, returning once the newest one settles.
  func refresh(instanceId: String) async {
    startRefresh(instanceId: instanceId)
    while let refreshTask {
      await refreshTask.value
    }
  }

  func loadPinnedItems(instanceId: String) async {
    guard !instanceId.isEmpty else {
      withAnimation {
        if !pinnedCollections.isEmpty { pinnedCollections = [] }
        if !pinnedReadLists.isEmpty { pinnedReadLists = [] }
      }
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      switch section.contentKind {
      case .collections:
        let loadedCollections = try await database.fetchPinnedCollectionDisplayItems(
          instanceId: instanceId
        )
        withAnimation {
          if pinnedCollections != loadedCollections {
            pinnedCollections = loadedCollections
          }
          if !pinnedReadLists.isEmpty { pinnedReadLists = [] }
        }
      case .readLists:
        let loadedReadLists = try await database.fetchPinnedReadListDisplayItems(
          instanceId: instanceId
        )
        withAnimation {
          if pinnedReadLists != loadedReadLists {
            pinnedReadLists = loadedReadLists
          }
          if !pinnedCollections.isEmpty { pinnedCollections = [] }
        }
      default:
        break
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func startRefresh(instanceId: String) {
    refreshTask?.cancel()
    let refreshID = UUID()
    self.refreshID = refreshID
    refreshingInstanceId = instanceId
    refreshTask = Task {
      await loadPinnedItems(instanceId: instanceId)
      if !AppConfig.isOffline, !Task.isCancelled {
        switch section.contentKind {
        case .collections:
          await SyncService.syncCollections(instanceId: instanceId)
        case .readLists:
          await SyncService.syncReadLists(instanceId: instanceId)
        default:
          break
        }
        if !Task.isCancelled {
          await loadPinnedItems(instanceId: instanceId)
        }
      }
      // A newer refresh that superseded this one owns `refreshTask` now.
      if refreshID == self.refreshID {
        refreshTask = nil
        refreshingInstanceId = nil
      }
    }
  }
}
