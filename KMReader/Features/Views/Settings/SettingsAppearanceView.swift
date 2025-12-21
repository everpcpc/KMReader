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
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("showSeriesCardTitle") private var showSeriesCardTitle: Bool = true
  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

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
    private enum ColumnButtonFocus: Hashable {
      case columnMinus
      case columnPlus
    }
    @FocusState private var columnFocusedButton: ColumnButtonFocus?
    @FocusState private var colorFocusedButton: ThemeColor?
  #endif

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.appearance.theme"))) {
        #if os(iOS) || os(macOS)
          ColorPicker(
            String(localized: "settings.appearance.color"),
            selection: themeColorBinding,
            supportsOpacity: false)
        #elseif os(tvOS)
          VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "settings.appearance.color"))
              .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
              ForEach(ThemeColor.presetColors, id: \.name) { preset in
                Button {
                  themeColor = preset.themeColor
                } label: {
                  ZStack {
                    Circle()
                      .fill(preset.color)
                      .frame(width: 50, height: 50)
                    if preset.themeColor == themeColor {
                      Circle()
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 50, height: 50)
                      Image(systemName: "checkmark")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .bold))
                    }
                  }
                }
                .focused($colorFocusedButton, equals: preset.themeColor)
                .adaptiveButtonStyle(.plain)
                .focusPadding()
              }
            }
            .focusSection()
          }
        #endif
      }

      Section(header: Text(String(localized: "settings.appearance.browse"))) {
        #if os(iOS)
          VStack(alignment: .leading, spacing: 8) {
            Stepper(
              value: portraitColumnsBinding,
              in: 1...8,
              step: 1
            ) {
              HStack {
                Text(String(localized: "settings.appearance.portraitColumns.label"))
                Text("\(browseColumns.portrait)")
                  .foregroundColor(.secondary)
              }
            }
            Text(String(localized: "settings.appearance.portraitColumns.caption"))
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
                Text(String(localized: "settings.appearance.landscapeColumns.label"))
                Text("\(browseColumns.landscape)")
                  .foregroundColor(.secondary)
              }
            }
            Text(String(localized: "settings.appearance.landscapeColumns.caption"))
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
                Text(String(localized: "settings.appearance.numberOfColumns.label"))
                Text("\(browseColumns.landscape)")
                  .foregroundColor(.secondary)
              }
            }
            Text(String(localized: "settings.appearance.numberOfColumns.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        #elseif os(tvOS)
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "settings.appearance.numberOfColumns.label"))
              Text(String(localized: "settings.appearance.numberOfColumns.caption"))
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
              .focused($columnFocusedButton, equals: .columnMinus)
              .adaptiveButtonStyle(.plain)
              Text("\(browseColumns.landscape)")
                .frame(minWidth: 30)
              Button {
                landscapeColumnsBinding.wrappedValue = min(
                  16, landscapeColumnsBinding.wrappedValue + 1)
              } label: {
                Image(systemName: "plus.circle.fill")
              }
              .focused($columnFocusedButton, equals: .columnPlus)
              .adaptiveButtonStyle(.plain)
            }
          }
        #endif

        Toggle(isOn: $searchIgnoreFilters) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.searchIgnoreFilters.title"))
            Text(String(localized: "settings.appearance.searchIgnoreFilters.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Section(header: Text(String(localized: "settings.appearance.cards"))) {
        Toggle(isOn: $showSeriesCardTitle) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.showSeriesCardTitles.title"))
            Text(String(localized: "settings.appearance.showSeriesCardTitles.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $showBookCardSeriesTitle) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.showBookCardSeriesTitles.title"))
            Text(String(localized: "settings.appearance.showBookCardSeriesTitles.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $thumbnailPreserveAspectRatio) {
          VStack(alignment: .leading, spacing: 4) {
            Text(
              String(localized: "settings.appearance.preserveThumbnailAspectRatio.title"))
            Text(
              String(localized: "settings.appearance.preserveThumbnailAspectRatio.caption")
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(String(localized: "settings.appearance.title"))
  }
}
