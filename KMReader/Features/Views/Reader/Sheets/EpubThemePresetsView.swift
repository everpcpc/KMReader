//
//  EpubThemePresetsView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct EpubThemePresetsView: View {
  let onApply: ((EpubReaderPreferences) -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \EpubThemePreset.updatedAt, order: .reverse) private var presets: [EpubThemePreset]

  @State private var presetToRename: EpubThemePreset?
  @State private var newName: String = ""

  init(onApply: ((EpubReaderPreferences) -> Void)? = nil) {
    self.onApply = onApply
  }

  var body: some View {
    SheetView(
      title: String(localized: "Theme Presets"),
      size: .medium,
      applyFormStyle: true
    ) {
      if presets.isEmpty {
        ContentUnavailableView {
          Label("No Theme Presets", systemImage: "bookmark.slash")
        } description: {
          Text(
            "Save your favorite EPUB reading themes for quick access"
          )
        }
      } else {
        List {
          Section(String(localized: "Saved Presets")) {
            ForEach(presets) { preset in
              presetRow(preset)
            }
          }
        }
      }
    }
    .alert(
      "Rename Preset",
      isPresented: .init(
        get: { presetToRename != nil },
        set: { if !$0 { presetToRename = nil } }
      )
    ) {
      TextField("Preset Name", text: $newName)
      Button("Cancel", role: .cancel) {
        presetToRename = nil
        newName = ""
      }
      Button("Rename") {
        if let preset = presetToRename {
          renamePreset(preset, to: newName)
        }
      }
    }
  }

  @ViewBuilder
  private func presetRow(_ preset: EpubThemePreset) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(preset.name)
          .font(.body)
        Text(preset.updatedAt, style: .relative)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Button {
        applyPreset(preset)
        dismiss()
      } label: {
        Image(systemName: "arrowshape.turn.up.forward")
          .foregroundColor(.accentColor)
      }
      .adaptiveButtonStyle(.plain)
    }
    #if !os(tvOS)
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          deletePreset(preset)
        } label: {
          Label("Delete", systemImage: "trash")
        }

        Button {
          newName = preset.name
          presetToRename = preset
        } label: {
          Label("Rename", systemImage: "pencil")
        }
        .tint(.blue)
      }
    #endif
    .contextMenu {
      Button {
        applyPreset(preset)
        dismiss()
      } label: {
        Label("Apply Preset", systemImage: "arrowshape.turn.up.forward")
      }

      Button {
        newName = preset.name
        presetToRename = preset
      } label: {
        Label("Rename", systemImage: "pencil")
      }

      Divider()

      Button(role: .destructive) {
        deletePreset(preset)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private func applyPreset(_ preset: EpubThemePreset) {
    if let preferences = preset.getPreferences() {
      if let onApply {
        onApply(preferences)
      } else {
        AppConfig.epubPreferences = preferences
      }
      ErrorManager.shared.notify(message: String(localized: "Preset applied: \(preset.name)"))
    }
  }

  private func deletePreset(_ preset: EpubThemePreset) {
    modelContext.delete(preset)
    try? modelContext.save()
  }

  private func renamePreset(_ preset: EpubThemePreset, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    preset.name = trimmed
    preset.updatedAt = Date()
    try? modelContext.save()

    presetToRename = nil
    self.newName = ""
  }
}
