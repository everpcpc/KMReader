//
//  SettingsBrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

struct SettingsBrowseView: View {
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue
  @AppStorage("coverOnlyCards") private var coverOnlyCards: Bool = false
  @AppStorage("showBookCardSeriesTitle") private var showBookCardSeriesTitle: Bool = true
  @AppStorage("thumbnailPreserveAspectRatio") private var thumbnailPreserveAspectRatio: Bool = true
  @AppStorage("thumbnailShowShadow") private var thumbnailShowShadow: Bool = true
  @AppStorage("thumbnailGlassEffect") private var thumbnailGlassEffect: Bool = false
  @AppStorage("thumbnailShowUnreadIndicator") private var thumbnailShowUnreadIndicator: Bool = true
  @AppStorage("thumbnailShowProgressBar") private var thumbnailShowProgressBar: Bool = true
  @AppStorage("searchIgnoreFilters") private var searchIgnoreFilters: Bool = false

  private var gridDensityBinding: Binding<GridDensity> {
    Binding(
      get: { GridDensity.closest(to: gridDensity) },
      set: { gridDensity = $0.rawValue }
    )
  }

  var body: some View {
    Form {
      Section(header: Text(String(localized: "settings.appearance.browse"))) {
        Picker(selection: gridDensityBinding) {
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
      }

      Section(header: Text(String(localized: "settings.appearance.search"))) {
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

        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
          Toggle(isOn: $thumbnailGlassEffect) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "settings.appearance.coverGlassEffect.title"))
              Text(String(localized: "settings.appearance.coverGlassEffect.caption"))
                .font(.caption)
                .foregroundColor(.secondary)
            }
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
    .inlineNavigationBarTitle(String(localized: "settings.browse.title"))
  }
}
