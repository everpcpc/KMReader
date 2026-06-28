//
// OfflineCoverSyncScopePicker.swift
//
//

import SwiftUI

struct OfflineCoverSyncScopePicker: View {
  let viewModel: OfflineCoverSyncViewModel
  let isDisabled: Bool
  @State private var isPickerPresented = false

  var body: some View {
    Button {
      isPickerPresented = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "square.stack.3d.up")
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(String(localized: "Libraries"))
            .foregroundStyle(.primary)
          Text(scopeTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .sheet(isPresented: $isPickerPresented) {
      OfflineCoverSyncLibraryPickerSheet(
        libraries: viewModel.libraries,
        selectedLibraryIds: viewModel.selectedLibraryIds
      ) { libraryIds in
        viewModel.selectLibraries(libraryIds)
      }
    }
    .accessibilityLabel(
      Text(
        String(
          localized: "offline.coverSync.scope.label",
          defaultValue: "Cover Sync Libraries"
        )
      )
    )
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
}
