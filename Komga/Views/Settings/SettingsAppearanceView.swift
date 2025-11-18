//
//  SettingsAppearanceView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct SettingsAppearanceView: View {
  @AppStorage("themeColorName") private var themeColor: ThemeColorOption = .orange
  @AppStorage("browseColumns") private var browseColumns: BrowseColumns = BrowseColumns()
  @AppStorage("browseShowCardTitles") private var browseShowCardTitles: Bool = true
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

  var body: some View {
    Form {
      Section(header: Text("Theme")) {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Color")
            Spacer()
            Text(themeColor.displayName)
              .foregroundColor(.secondary)
          }

          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12
          ) {
            ForEach(ThemeColorOption.allCases, id: \.self) { option in
              Button {
                themeColor = option
              } label: {
                Circle()
                  .fill(option.color)
                  .frame(width: 40, height: 40)
                  .overlay(
                    Circle()
                      .stroke(
                        themeColor == option
                          ? Color.primary : Color.primary.opacity(0.2),
                        lineWidth: themeColor == option ? 3 : 1
                      )
                  )
                  .overlay(
                    Group {
                      if themeColor == option {
                        Image(systemName: "checkmark")
                          .font(.system(size: 16, weight: .bold))
                          .foregroundColor(.white)
                          .shadow(color: .black.opacity(0.3), radius: 1)
                      }
                    }
                  )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 4)
        }
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

        VStack(alignment: .leading, spacing: 8) {
          Toggle(isOn: $browseShowCardTitles) {
            Text("Show Card Titles")
          }
          Text("Show titles for series and books in the library view card")
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
    .navigationBarTitleDisplayMode(.inline)
  }
}
