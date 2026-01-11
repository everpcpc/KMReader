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
  @AppStorage("privacyProtection") private var privacyProtection: Bool = false

  private var themeColorBinding: Binding<Color> {
    Binding(
      get: { themeColor.color },
      set: { newColor in
        themeColor = ThemeColor(color: newColor)
      }
    )
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

      Section(header: Text(String(localized: "settings.appearance.privacy"))) {
        Toggle(isOn: $privacyProtection) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.privacyProtection.title"))
            Text(String(localized: "settings.appearance.privacyProtection.caption"))
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
