//
//  SettingsAppearanceView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct SettingsAppearanceView: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("browseLayout") private var browseLayout: BrowseLayoutMode = .grid
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("showSeriesCardTitle") private var showSeriesCardTitle: Bool = true
  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true

  private var portraitColumnsBinding: Binding<Int> {
    Binding(
      get: { browseColumns.portrait },
      set: { newValue in
        var updated = browseColumns
        updated.portrait = newValue
        browseColumns = updated
      }
    )
  }

  private var landscapeColumnsBinding: Binding<Int> {
    Binding(
      get: { browseColumns.landscape },
      set: { newValue in
        var updated = browseColumns
        updated.landscape = newValue
        browseColumns = updated
      }
    )
  }

  private var themeColorBinding: Binding<Color> {
    Binding(
      get: { themeColor.color },
      set: { newColor in
        themeColor = ThemeColor(color: newColor)
      }
    )
  }

  #if os(tvOS)
    private func isSelected(_ color: Color) -> Bool {
      // Compare colors by converting to hex strings
      let currentHex = themeColor.rawValue
      let presetHex = ThemeColor(color: color).rawValue
      return currentHex == presetHex
    }

    private enum ColumnButtonFocus: Hashable {
      case portraitMinus
      case portraitPlus
      case landscapeMinus
      case landscapePlus
    }
    @FocusState private var focusedButton: ColumnButtonFocus?
  #endif

  var body: some View {
    Form {
      Section(header: Text("Theme")) {
        #if os(iOS) || os(macOS)
          ColorPicker("Color", selection: themeColorBinding, supportsOpacity: false)
        #else
          VStack(alignment: .leading, spacing: 12) {
            Text("Color")
              .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
              ForEach(ThemeColor.presetColors, id: \.name) { preset in
                Button {
                  themeColor = ThemeColor(color: preset.color)
                } label: {
                  ZStack {
                    Circle()
                      .fill(preset.color)
                      .frame(width: 50, height: 50)
                    if isSelected(preset.color) {
                      Circle()
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 50, height: 50)
                      Image(systemName: "checkmark")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .bold))
                    }
                  }
                }
              }
            }
          }
        #endif
      }

      Section(header: Text("Browse")) {
        Picker("Layout", selection: $browseLayout) {
          ForEach(BrowseLayoutMode.allCases) { mode in
            Label(mode.displayName, systemImage: mode.iconName).tag(mode)
          }
        }
        .optimizedPickerStyle()

        #if os(iOS)
          VStack(alignment: .leading, spacing: 8) {
            Stepper(
              value: portraitColumnsBinding,
              in: 1...8,
              step: 1
            ) {
              HStack {
                Text("Portrait Columns")
                Text("\(browseColumns.portrait)")
                  .foregroundColor(.secondary)
              }
            }
            Text("Number of columns in portrait orientation for grid browse layout")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          VStack(alignment: .leading, spacing: 8) {
            Stepper(
              value: landscapeColumnsBinding,
              in: 1...16,
              step: 1
            ) {
              HStack {
                Text("Landscape Columns")
                Text("\(browseColumns.landscape)")
                  .foregroundColor(.secondary)
              }
            }
            Text("Number of columns in landscape orientation for grid browse layout")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        #elseif os(macOS)
          VStack(alignment: .leading, spacing: 8) {
            Stepper(
              value: landscapeColumnsBinding,
              in: 1...16,
              step: 1
            ) {
              HStack {
                Text("Number of Columns")
                Text("\(browseColumns.landscape)")
                  .foregroundColor(.secondary)
              }
            }
            Text("Number of columns for grid browse layout")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        #else
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Number of Columns")
              Text("Number of columns for grid browse layout")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 36) {
              Button {
                landscapeColumnsBinding.wrappedValue = max(
                  1, landscapeColumnsBinding.wrappedValue - 1)
              } label: {
                Image(systemName: "minus.circle.fill")
              }
              #if os(tvOS)
                .focused($focusedButton, equals: .landscapeMinus)
                .adaptiveButtonStyle(.plain)
              #endif
              Text("\(browseColumns.landscape)")
                .frame(minWidth: 30)
              Button {
                landscapeColumnsBinding.wrappedValue = min(
                  16, landscapeColumnsBinding.wrappedValue + 1)
              } label: {
                Image(systemName: "plus.circle.fill")
              }
              #if os(tvOS)
                .focused($focusedButton, equals: .landscapePlus)
                .adaptiveButtonStyle(.plain)
              #endif
            }
          }
        #endif
      }

      Section(header: Text("Cards")) {
        Toggle(isOn: $showSeriesCardTitle) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Show Series Card Titles")
            Text("Show titles for series in view cards")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $showBookCardSeriesTitle) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Show Book Card Series Titles")
            Text("Show series titles for books in view cards")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $thumbnailPreserveAspectRatio) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Preserve Thumbnail Aspect Ratio")
            Text("Preserve aspect ratio for thumbnail images")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle("Appearance")
  }
}
