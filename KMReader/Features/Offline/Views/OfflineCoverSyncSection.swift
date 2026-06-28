//
// OfflineCoverSyncSection.swift
//
//

import SwiftUI

struct OfflineCoverSyncSection: View {
  let viewModel: OfflineCoverSyncViewModel
  let instanceId: String
  let isOffline: Bool

  private var isStartDisabled: Bool {
    !viewModel.isSyncing && (isOffline || instanceId.isEmpty)
  }

  var body: some View {
    Section {
      Button(role: viewModel.isSyncing ? .destructive : nil) {
        handleCoverSyncButton()
      } label: {
        HStack {
          Label(actionTitle, systemImage: actionIcon)
          Spacer()
          if viewModel.isSyncing {
            ProgressView()
              .controlSize(.small)
          }
        }
      }
      .disabled(isStartDisabled)

      OfflineCoverSyncScopeMenu(
        viewModel: viewModel,
        isDisabled: viewModel.isSyncing || isOffline || instanceId.isEmpty
      )

      if viewModel.isSyncing {
        if let progress = viewModel.progress, progress.totalCount > 0 {
          OfflineCoverSyncProgressView(progress: progress)
            .padding(.vertical, 4)
        } else {
          Text(String(localized: "offline.coverSync.checking", defaultValue: "Checking covers…"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } header: {
      Text(String(localized: "offline.coverSync.section", defaultValue: "Cover Sync"))
    }
    .task(id: instanceId) {
      await viewModel.loadLibraryScopeOptions(instanceId: instanceId)
    }
    .onChange(of: instanceId) { _, newValue in
      viewModel.cancelSyncIfContextChanged(instanceId: newValue, isOffline: isOffline)
    }
    .onChange(of: isOffline) { _, newValue in
      viewModel.cancelSyncIfContextChanged(instanceId: instanceId, isOffline: newValue)
    }
  }

  private var actionTitle: String {
    if viewModel.isSyncing {
      return String(localized: "offline.coverSync.cancel", defaultValue: "Cancel Cover Sync")
    }
    return String(localized: "offline.coverSync.action", defaultValue: "Sync Missing Covers")
  }

  private var actionIcon: String {
    viewModel.isSyncing ? "xmark.circle" : "photo.on.rectangle.angled"
  }

  private func handleCoverSyncButton() {
    if viewModel.isSyncing {
      viewModel.cancelSync()
      return
    }

    let libraryIds = viewModel.selectedLibraryIdsForSync(instanceId: instanceId)
    viewModel.startSyncMissingCovers(instanceId: instanceId, libraryIds: libraryIds)
  }
}
