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
  @AppStorage("dashboardShowGradient") private var dashboardShowGradient: Bool = true
  @AppStorage("enableHandoff") private var enableHandoff: Bool = true

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
        #endif

        Toggle(isOn: $dashboardShowGradient) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "dashboard.gradient.title"))
            Text(String(localized: "dashboard.gradient.caption"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
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

        Toggle(isOn: $enableHandoff) {
          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "settings.appearance.handoff.title"))
            Text(String(localized: "settings.appearance.handoff.caption"))
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
