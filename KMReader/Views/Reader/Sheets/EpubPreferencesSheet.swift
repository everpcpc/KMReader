//
//  EpubPreferencesSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import CoreText
import ReadiumNavigator
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

struct EpubPreferencesSheet: View {
  let onApply: (EpubReaderPreferences) -> Void
  @State private var draft: EpubReaderPreferences
  @State private var showCustomFontsSheet: Bool = false
  @State private var fontListRefreshId: UUID = UUID()

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
            ForEach(FontProvider.allChoices, id: \.id) { choice in
              Text(choice.rawValue).tag(choice)
            }
          }
          .id(fontListRefreshId)
          VStack(alignment: .leading) {
            Slider(value: $draft.fontSize, in: 0.5...2.0, step: 0.05)
            Text("Size: \(String(format: "%.2f", draft.fontSize))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Button {
            showCustomFontsSheet = true
          } label: {
            HStack {
              Label("Manage Custom Fonts", systemImage: "textformat")
              Spacer()
              if !AppConfig.customFontNames.isEmpty {
                Text("\(AppConfig.customFontNames.count)")
                  .foregroundStyle(.secondary)
              }
              Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
            }
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
      .sheet(isPresented: $showCustomFontsSheet) {
        CustomFontsSheet()
          .onDisappear {
            // Refresh font list when custom fonts sheet is dismissed
            FontProvider.refresh()
            fontListRefreshId = UUID()

            // If current selection is a removed font, reset to publisher default
            if !AppConfig.customFontNames.contains(draft.fontFamily.rawValue)
              && draft.fontFamily != .publisher
              && !FontProvider.allChoices.contains(where: {
                $0.rawValue == draft.fontFamily.rawValue
              })
            {
              draft.fontFamily = .publisher
            }
          }
      }
    }
  }
}

enum FontProvider {
  private static var _allChoices: [FontFamilyChoice]?

  static var allChoices: [FontFamilyChoice] {
    if let cached = _allChoices {
      return cached
    }
    return loadFonts()
  }

  static func refresh() {
    _allChoices = nil
  }

  private static func loadFonts() -> [FontFamilyChoice] {
    // Only use custom fonts, not system fonts
    let customFonts = AppConfig.customFontNames
    let sorted = customFonts.sorted()
    let customChoices = sorted.map { FontFamilyChoice.system($0) }

    _allChoices = [.publisher] + customChoices
    return _allChoices!
  }
}
