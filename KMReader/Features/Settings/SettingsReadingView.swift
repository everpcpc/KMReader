//
// SettingsReadingView.swift
//
//

#if os(iOS) || os(tvOS)
  import SwiftUI

  struct SettingsReadingView: View {
    @AppStorage("keepScreenAwakeWhileReading") private var keepScreenAwakeWhileReading: Bool = false

    var body: some View {
      Form {
        Section {
          Toggle(isOn: $keepScreenAwakeWhileReading) {
            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 6) {
                Image(systemName: "sun.max")
                Text(String(localized: "Keep Screen Awake While Reading"))
              }
              Text(String(localized: "Prevents the screen from dimming or locking while a reader is open."))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        } header: {
          Text(String(localized: "Screen"))
        } footer: {
          Text(
            String(
              localized:
                "Applies to all readers (DIVINA, EPUB, and PDF). The screen returns to normal when you close the reader."
            )
          )
        }
      }
      .formStyle(.grouped)
      .inlineNavigationBarTitle(SettingsSection.reading.title)
    }
  }
#endif
