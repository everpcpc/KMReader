//
// OfflineCoverSyncSection.swift
//
//

import SwiftUI

struct OfflineCoverSyncSection: View {
  let viewModel: OfflineCoverSyncViewModel
  let instanceId: String
  let isOffline: Bool
  @State private var isPickerPresented = false

  private var isStartDisabled: Bool {
    !viewModel.isSyncing && (isOffline || instanceId.isEmpty)
  }

  private var isPickerDisabled: Bool {
    viewModel.isSyncing || isOffline || instanceId.isEmpty
  }

  var body: some View {
    Section {
      HStack(spacing: 12) {
        Button {
          guard !isPickerDisabled else { return }
          isPickerPresented = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
              .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
              Text(String(localized: "offline.coverSync.section", defaultValue: "Cover Sync"))
                .foregroundStyle(.primary)
              statusLine
            }
            Spacer(minLength: 0)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPickerDisabled && !viewModel.isSyncing)
        .accessibilityLabel(
          Text(
            String(
              localized: "offline.coverSync.scope.label",
              defaultValue: "Cover Sync Libraries"
            )
          )
        )

        Button(role: viewModel.isSyncing ? .destructive : nil) {
          handleCoverSyncButton()
        } label: {
          actionLabel
        }
        .buttonStyle(.bordered)
        .disabled(isStartDisabled)
        .accessibilityLabel(Text(actionAccessibilityLabel))
      }
    }
    .sheet(isPresented: $isPickerPresented) {
      OfflineCoverSyncLibraryPickerSheet(
        libraries: viewModel.libraries,
        selectedLibraryIds: viewModel.selectedLibraryIds
      ) { libraryIds in
        viewModel.selectLibraries(libraryIds)
      }
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

  @ViewBuilder
  private var statusLine: some View {
    if viewModel.isSyncing {
      if let progress = viewModel.progress, progress.totalCount > 0 {
        OfflineCoverSyncProgressView(progress: progress)
      } else {
        Text(String(localized: "offline.coverSync.checking", defaultValue: "Checking covers…"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else {
      HStack(spacing: 4) {
        Text(scopeTitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Image(systemName: "chevron.right")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  @ViewBuilder
  private var actionLabel: some View {
    if viewModel.isSyncing {
      Label(String(localized: "Cancel"), systemImage: "xmark.circle")
    } else {
      Label(
        String(localized: "offline.sync.confirm.action", defaultValue: "Sync Now"),
        systemImage: "arrow.triangle.2.circlepath"
      )
    }
  }

  private var actionAccessibilityLabel: String {
    if viewModel.isSyncing {
      return String(localized: "offline.coverSync.cancel", defaultValue: "Cancel Cover Sync")
    }
    return String(localized: "offline.coverSync.action", defaultValue: "Sync Missing Covers")
  }

  private var scopeTitle: String {
    if viewModel.syncsAllLibraries {
      return String(localized: "offline.coverSync.scope.all", defaultValue: "All Libraries")
    }

    if viewModel.selectedLibraryIds.count == 1,
      let selectedLibraryId = viewModel.selectedLibraryIds.first,
      let selectedLibrary = viewModel.libraries.first(where: { $0.id == selectedLibraryId })
    {
      return selectedLibrary.name
    }

    let format = String(
      localized: "offline.coverSync.scope.selected",
      defaultValue: "%lld Libraries"
    )
    return String.localizedStringWithFormat(format, viewModel.selectedLibraryIds.count)
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
