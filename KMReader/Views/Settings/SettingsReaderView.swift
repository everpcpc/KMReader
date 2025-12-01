//
//  SettingsReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsReaderView: View {
  @AppStorage("showReaderHelperOverlay") private var showReaderHelperOverlay: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("pageLayout") private var pageLayout: PageLayout = .dual
  @AppStorage("dualPageNoCover") private var dualPageNoCover: Bool = false
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0

  var body: some View {
    List {
      Section(header: Text("Overlay Hints")) {
        #if os(macOS)
          Toggle(isOn: $showReaderHelperOverlay) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show Keyboard Help Overlay")
              Text("Briefly show keyboard shortcuts when opening the reader")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #else
          Toggle(isOn: $showReaderHelperOverlay) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show Tap Zone Hints")
              Text("Display tap zone hints when entering reader")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #endif
      }

      Section(header: Text("Background")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Reader Background", selection: $readerBackground) {
            ForEach(ReaderBackground.allCases, id: \.self) { background in
              Text(background.displayName).tag(background)
            }
          }
          #if os(macOS)
            .pickerStyle(.radioGroup)
          #else
            .pickerStyle(.segmented)
          #endif
          Text("The background color of the reader")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Section(header: Text("Page Display")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Page Layout", selection: $pageLayout) {
            ForEach(PageLayout.allCases, id: \.self) { mode in
              Label(mode.displayName, systemImage: mode.icon)
                .tag(mode)
            }
          }
          .optimizedPickerStyle()
          Text("Single page or dual page (only in landscape)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Toggle(isOn: $dualPageNoCover) {
          VStack(alignment: .leading, spacing: 4) {
            Text("No Cover in Dual Page")
            Text("Don't show the cover page in dual page mode")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      #if os(iOS)
        Section(header: Text("Webtoon")) {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Page Width")
              Spacer()
              Text("\(Int(webtoonPageWidthPercentage))%")
                .foregroundColor(.secondary)
            }
            Slider(
              value: $webtoonPageWidthPercentage,
              in: 50...100,
              step: 5
            )
            Text("Adjust the width of webtoon pages as a percentage of screen width")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      #endif
    }
    .optimizedListStyle()
    .inlineNavigationBarTitle("Reader")
  }
}
