//
//  EpubPreferencesSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import CoreText
import ReadiumNavigator
import SwiftUI

struct EpubPreferencesSheet: View {
  let onApply: (EpubReaderPreferences) -> Void
  @State private var draft: EpubReaderPreferences

  @Environment(\.dismiss) private var dismiss

  init(_ pref: EpubReaderPreferences, onApply: @escaping (EpubReaderPreferences) -> Void) {
    self._draft = State(initialValue: pref)
    self.onApply = onApply
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Font") {
          Picker("Typeface", selection: $draft.fontFamily) {
            ForEach(FontProvider.allChoices) { choice in
              Text(choice.rawValue).tag(choice)
            }
          }
          VStack(alignment: .leading) {
            Slider(value: $draft.typeScale, in: 0.8...1.4, step: 0.05)
            Text("Size: \(Int(draft.typeScale * 100))%")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section("Pagination") {
          Picker("Reading Mode", selection: $draft.pagination) {
            ForEach(PaginationMode.allCases) { mode in
              Label(mode.title, systemImage: mode.icon).tag(mode)
            }
          }
          Picker("Page Layout", selection: $draft.layout) {
            ForEach(LayoutChoice.allCases) { layout in
              Label(layout.title, systemImage: layout.icon).tag(layout)
            }
          }
        }

        Section("Theme") {
          Picker("Appearance", selection: $draft.theme) {
            ForEach(ThemeChoice.allCases) { choice in
              Text(choice.title).tag(choice)
            }
          }
          .pickerStyle(.segmented)
        }
      }
      .navigationTitle("Reading Options")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            dismiss()
          } label: {
            Label("Cancel", systemImage: "xmark")
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            onApply(draft)
            dismiss()
          } label: {
            Label("Save", systemImage: "checkmark")
          }
        }
      }
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }
}

private enum FontProvider {
  static let allChoices: [FontFamilyChoice] = {
    let names = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
    let sorted = names.sorted()
    return [.publisher] + sorted.map { .system($0) }
  }()
}
