//
//  ReaderSettingsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReaderSettingsSheet: View {
  // Session-specific bindings (not persisted until reader closes)
  @Binding var readingDirection: ReadingDirection
  @Binding var pageLayout: PageLayout
  @Binding var dualPageNoCover: Bool

  // Persisted settings (via @AppStorage)
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("webtoonTapScrollPercentage") private var webtoonTapScrollPercentage: Double = 80.0
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0
  @AppStorage("scrollPageTransitionStyle") private var scrollPageTransitionStyle: ScrollPageTransitionStyle = .default
  @AppStorage("disableTapToTurnPage") private var disableTapToTurnPage: Bool = false
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("autoFullscreenOnOpen") private var autoFullscreenOnOpen: Bool = false
  @AppStorage("controlsAutoHide") private var controlsAutoHide: Bool = true
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false

  var body: some View {
    SheetView(
      title: String(localized: "Reader Settings"), size: .both, applyFormStyle: true
    ) {
      Form {

        // MARK: - Session Reading Options Section (not persisted)

        Section(header: Text("Current Reading Options")) {
          VStack(alignment: .leading, spacing: 8) {
            Picker("Reading Direction", selection: $readingDirection) {
              ForEach(ReadingDirection.availableCases, id: \.self) { direction in
                Label(direction.displayName, systemImage: direction.icon)
                  .tag(direction)
              }
            }
            .pickerStyle(.menu)
            Text("Only applies to current reading session")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          if readingDirection != .webtoon && readingDirection != .vertical {
            VStack(alignment: .leading, spacing: 8) {
              Picker("Page Layout", selection: $pageLayout) {
                ForEach(PageLayout.allCases, id: \.self) { layout in
                  Label(layout.displayName, systemImage: layout.icon)
                    .tag(layout)
                }
              }
              .pickerStyle(.menu)
              Text("Only applies to current reading session")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if pageLayout.supportsDualPageOptions {
              Toggle(isOn: $dualPageNoCover) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Show Cover in Dual Spread")
                  Text("Only applies to current reading session")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        // MARK: - Appearance Section

        Section(header: Text("Appearance")) {
          Picker("Reader Background", selection: $readerBackground) {
            ForEach(ReaderBackground.allCases, id: \.self) { background in
              Text(background.displayName).tag(background)
            }
          }
          .pickerStyle(.menu)

          #if os(iOS)
            if readingDirection != .webtoon {
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
              }
            }
          #endif

          Toggle(isOn: $showPageNumber) {
            Text("Always Show Page Number")
          }

          #if os(iOS) || os(macOS)
            if readingDirection == .webtoon {
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
              }
            }
          #endif

          #if os(macOS)
            Toggle(isOn: $autoFullscreenOnOpen) {
              Text("Auto Full Screen on Open")
            }
          #endif

          Toggle(isOn: $controlsAutoHide) {
            Text("Auto Hide Controls")
          }

          #if !os(tvOS)
            Toggle(isOn: $enableLiveText) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Enable Live Text")
                Text("Automatically enable Live Text for all images.")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          #endif
        }

        // MARK: - Page Turn Section

        Section(header: Text("Page Turn")) {
          if readingDirection != .webtoon {
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

          #if os(macOS)
            Toggle(isOn: $showKeyboardHelpOverlay) {
              Text("Show Keyboard Help Overlay")
            }
          #endif

          #if os(iOS) || os(macOS)
            Toggle(isOn: $disableTapToTurnPage) {
              Text("Disable Tap to Turn Page")
            }

            if !disableTapToTurnPage {
              Toggle(isOn: $showTapZoneHints) {
                Text("Show Tap Zone Hints")
              }

              VStack(alignment: .leading, spacing: 8) {
                Picker("Tap Zone Size", selection: $tapZoneSize) {
                  ForEach(TapZoneSize.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                  }
                }
                .pickerStyle(.menu)

                TapZonePreview(size: tapZoneSize, direction: readingDirection)
                  .frame(height: 60)

                Text("Size of tap zones for page navigation")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              if readingDirection == .webtoon {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text("Webtoon Tap Scroll Height")
                    Spacer()
                    Text("\(Int(webtoonTapScrollPercentage))%")
                      .foregroundColor(.secondary)
                  }
                  Slider(
                    value: $webtoonTapScrollPercentage,
                    in: 25...100,
                    step: 5
                  )
                  Text("Scroll distance when tapping to navigate in webtoon mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              } else {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text("Tap Page Scroll Duration")
                    Spacer()
                    Text(
                      tapPageTransitionDuration == 0
                        ? String(localized: "None")
                        : String(format: "%.1fs", tapPageTransitionDuration)
                    )
                    .foregroundColor(.secondary)
                  }
                  Slider(
                    value: $tapPageTransitionDuration,
                    in: 0...1,
                    step: 0.1
                  )
                }
              }
            }
          #endif
        }
      }
    }
    .animation(.default, value: disableTapToTurnPage)
    .presentationDragIndicator(.visible)
  }
}
