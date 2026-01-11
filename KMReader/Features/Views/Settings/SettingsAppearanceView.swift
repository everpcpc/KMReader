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
  @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  private var themeColorBinding: Binding<Color> {
    Binding(
      get: { themeColor.color },
      set: { newColor in
        themeColor = ThemeColor(color: newColor)
      }
    )
  }

  private var selectedDensity: GridDensity {
    GridDensity.closest(to: gridDensity)
  }

  #if os(tvOS)
    @FocusState private var colorFocusedButton: ThemeColor?
  #endif

  var body: some View {
    Form {
      #if os(iOS)
        Section(header: Text(String(localized: "settings.appearance.language"))) {
          Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "settings.appearance.language.change"))
                Text(String(localized: "settings.appearance.language.caption"))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Image(systemName: "arrow.up.forward.app")
                .foregroundColor(.secondary)
            }
          }
        }
      #endif

      Section(header: Text(String(localized: "settings.appearance.theme"))) {
        Picker(
          String(localized: "settings.appearance.colorScheme.title"),
          selection: $appColorScheme
        ) {
          ForEach(AppColorScheme.allCases) { scheme in
            Text(scheme.label).tag(scheme)
          }
        }

        #if os(iOS)
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
        Picker(
          selection: Binding(
            get: { selectedDensity },
            set: { gridDensity = $0.rawValue }
          )
        ) {
          ForEach(GridDensity.allCases, id: \.self) { density in
            Text(density.label).tag(density)
          }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.gridDensity.label"))
            Text(String(localized: "settings.appearance.gridDensity.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

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
        Toggle(isOn: $coverOnlyCards) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.coverOnlyCards.title"))
            Text(String(localized: "settings.appearance.coverOnlyCards.caption"))
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
              String(localized: "settings.appearance.preserveCoverAspectRatio.title"))
            Text(
              String(localized: "settings.appearance.preserveCoverAspectRatio.caption")
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $thumbnailShowShadow) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.coverShowShadow.title"))
            Text(String(localized: "settings.appearance.coverShowShadow.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $thumbnailShowUnreadIndicator) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.coverShowUnreadIndicator.title"))
            Text(String(localized: "settings.appearance.coverShowUnreadIndicator.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $thumbnailShowProgressBar) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.coverShowProgressBar.title"))
            Text(String(localized: "settings.appearance.coverShowProgressBar.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.appearance.title)
  }
}
