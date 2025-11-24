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

  var body: some View {
    List {
      Section(header: Text("Theme")) {
        ColorPicker("Color", selection: themeColorBinding, supportsOpacity: false)
      }

      Section(header: Text("Browse")) {
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
          Text("Number of columns in portrait orientation")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          Stepper(
            value: landscapeColumnsBinding,
            in: 1...8,
            step: 1
          ) {
            HStack {
              Text("Landscape Columns")
              Text("\(browseColumns.landscape)")
                .foregroundColor(.secondary)
            }
          }
          Text("Number of columns in landscape orientation")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Section(header: Text("Cards")) {
        VStack(alignment: .leading, spacing: 8) {
          Toggle(isOn: $showSeriesCardTitle) {
            Text("Show Series Card Titles")
          }
          Text("Show titles for series in view cards")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          Toggle(isOn: $showBookCardSeriesTitle) {
            Text("Show Book Card Series Titles")
          }
          Text("Show series titles for books in view cards")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          Toggle(isOn: $thumbnailPreserveAspectRatio) {
            Text("Preserve Thumbnail Aspect Ratio")
          }
          Text("Preserve aspect ratio for thumbnail images")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .navigationTitle("Appearance")
    #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}
