//
// OfflineCoverSyncScopeMenu.swift
//
//

import SwiftUI

struct OfflineCoverSyncScopeMenu: View {
  let viewModel: OfflineCoverSyncViewModel
  let isDisabled: Bool

  var body: some View {
    Menu {
      Button {
        viewModel.selectAllLibraries()
      } label: {
        Label(
          String(localized: "offline.coverSync.scope.all", defaultValue: "All Libraries"),
          systemImage: viewModel.syncsAllLibraries ? "checkmark.circle.fill" : "circle"
        )
      }

      if !viewModel.libraries.isEmpty {
        Divider()

        ForEach(viewModel.libraries) { library in
          Button {
            viewModel.toggleLibrarySelection(library.id)
          } label: {
            Label(
              library.name,
              systemImage: viewModel.selectedLibraryIds.contains(library.id)
                ? "checkmark.circle.fill" : "circle"
            )
          }
        }
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "square.stack.3d.up")
          .imageScale(.small)
        Text(scopeTitle)
          .lineLimit(1)
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      .contentShape(Rectangle())
    }
    .disabled(isDisabled)
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
