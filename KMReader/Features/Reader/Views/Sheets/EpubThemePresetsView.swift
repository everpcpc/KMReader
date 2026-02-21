//
// EpubThemePresetsView.swift
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct EpubThemePresetsView: View {
  let onApply: ((EpubReaderPreferences) -> Void)?

  @Environment(\.dismiss) private var dismiss
  @FetchAll(EpubThemePresetRecord.order { $0.updatedAt.desc() }) private var presets: [EpubThemePresetRecord]
  @Dependency(\.defaultDatabase) private var database

  @State private var presetToRename: EpubThemePresetRecord?
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
  private func presetRow(_ preset: EpubThemePresetRecord) -> some View {
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

  private func applyPreset(_ preset: EpubThemePresetRecord) {
    if let preferences = EpubReaderPreferences(rawValue: preset.preferencesJSON) {
      if let onApply {
        onApply(preferences)
      } else {
        AppConfig.epubPreferences = preferences
      }
      ErrorManager.shared.notify(message: String(localized: "Preset applied: \(preset.name)"))
    }
  }

  private func deletePreset(_ preset: EpubThemePresetRecord) {
    do {
      try database.write { db in
        try EpubThemePresetRecord.find(preset.id).delete().execute(db)
      }
    } catch {
      ErrorManager.shared.alert(message: "Failed to delete preset: \(error.localizedDescription)")
    }
  }

  private func renamePreset(_ preset: EpubThemePresetRecord, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    let now = Date()

    do {
      try database.write { db in
        try EpubThemePresetRecord
          .find(preset.id)
          .update {
            $0.name = #bind(trimmed)
            $0.updatedAt = #bind(now)
          }
          .execute(db)
      }

      presetToRename = nil
      self.newName = ""
    } catch {
      ErrorManager.shared.alert(message: "Failed to rename preset: \(error.localizedDescription)")
    }
  }
}
