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
        VStack(alignment: .leading, spacing: 8) {
          Picker(String(localized: "settings.appearance.gridDensity.label"), selection: gridDensityBinding) {
            ForEach(GridDensity.allCases, id: \.self) { density in
              Text(density.label).tag(density)
            }
          }
          .pickerStyle(.menu)
          Text(String(localized: "settings.appearance.gridDensity.caption"))
            .font(.caption)
            .foregroundColor(.secondary)
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
        HStack(spacing: 12) {
          SettingsBrowseCardPreview(
            title: "Series Title",
            detail: "12 books",
            unreadCount: 3
          )
          .frame(maxWidth: .infinity)

          SettingsBrowseCardPreview(
            title: "#12 - Book Title",
            subtitle: "Series Title",
            detail: "200 pages",
            progress: 0.45
          )
          .frame(maxWidth: .infinity)

          SettingsBrowseCardPreview(
            title: "#1 - Book Title",
            subtitle: "Series Title",
            detail: "200 pages",
            showUnreadDot: true
          )
          .frame(maxWidth: .infinity)
        }

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
    .inlineNavigationBarTitle(String(localized: "settings.browse.title"))
  }
}
