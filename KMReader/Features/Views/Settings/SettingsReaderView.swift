//
//  SettingsReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsReaderView: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("pageLayout") private var pageLayout: PageLayout = .auto
  @AppStorage("dualPageNoCover") private var dualPageNoCover: Bool = false
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("defaultReadingDirection") private var readDirection: ReadingDirection = .ltr
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2
  @AppStorage("scrollPageTransitionStyle") private var scrollPageTransitionStyle:
    ScrollPageTransitionStyle = .default
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0

  var body: some View {
    Form {
      Section(header: Text("Appearance")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Reader Background", selection: $readerBackground) {
            ForEach(ReaderBackground.allCases, id: \.self) { background in
              Text(background.displayName).tag(background)
            }
          }
          .pickerStyle(.menu)
          Text("The background color of the reader")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        #if os(iOS) || os(macOS)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Tap Page Transition")
              Spacer()
              Text(
                tapPageTransitionDuration == 0
                  ? String(localized: "None") : String(format: "%.1fs", tapPageTransitionDuration)
              )
              .foregroundColor(.secondary)
            }
            Slider(
              value: $tapPageTransitionDuration,
              in: 0...1,
              step: 0.1
            )
            Text("Animation duration when tapping to turn pages")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        #endif

        VStack(alignment: .leading, spacing: 8) {
          Picker("Scroll Page Transition", selection: $scrollPageTransitionStyle) {
            ForEach(ScrollPageTransitionStyle.allCases, id: \.self) { style in
              Text(style.displayName).tag(style)
            }
          }
          .pickerStyle(.menu)
          Text(scrollPageTransitionStyle.description)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Section(header: Text("Controls")) {
        Toggle(isOn: $disableTapToTurnPage) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Disable Tap to Turn Page")
            Text("Tap will only show/hide controls, not turn pages")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        if !disableTapToTurnPage {
          Toggle(isOn: $showTapZoneHints) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show Tap Zone Hints")
              Text("Display tap zone hints when opening the reader")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        #if os(macOS)
          Toggle(isOn: $showKeyboardHelpOverlay) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show Keyboard Help Overlay")
              Text("Briefly show keyboard shortcuts when opening the reader")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #endif

        #if os(iOS)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Double Tap Zoom Scale")
              Spacer()
              Text(String(format: "%.1fx", doubleTapZoomScale))
                .foregroundColor(.secondary)
            }
            Slider(
              value: $doubleTapZoomScale,
              in: 1.0...8.0,
              step: 0.5
            )
            Text("Zoom level when double-tapping on a page")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        #endif
      }

      Section(header: Text("Default Reading Options")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Preferred Direction", selection: $readDirection) {
            ForEach(ReadingDirection.availableCases, id: \.self) { direction in
              Label(direction.displayName, systemImage: direction.icon)
                .tag(direction)
            }
          }
          .pickerStyle(.menu)
          Text("Used when a book or series doesn't specify a reading direction")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          Picker("Page Layout", selection: $pageLayout) {
            ForEach(PageLayout.allCases, id: \.self) { mode in
              Label(mode.displayName, systemImage: mode.icon)
                .tag(mode)
            }
          }
          .pickerStyle(.menu)
          Text("Opt for single page, auto-detected spreads, or forced dual pages (landscape only)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        if pageLayout.supportsDualPageOptions {
          Toggle(isOn: $dualPageNoCover) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show Cover in Dual Spread")
              Text("Display the cover alongside the next page when using dual page mode")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        Toggle(isOn: $showPageNumber) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Always Show Page Number")
            Text("Display page number overlay on images while reading")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        #if os(iOS) || os(macOS)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Webtoon Page Width")
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
        #endif
      }
    }
    .animation(.default, value: disableTapToTurnPage)
    .formStyle(.grouped)
    .inlineNavigationBarTitle(String(localized: "title.reader"))
  }
}
