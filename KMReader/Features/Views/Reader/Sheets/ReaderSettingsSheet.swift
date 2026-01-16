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

  // Persisted settings (via @AppStorage)
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("webtoonTapScrollPercentage") private var webtoonTapScrollPercentage: Double = 80.0
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 2.0
  @AppStorage("scrollPageTransitionStyle") private var scrollPageTransitionStyle: ScrollPageTransitionStyle = .default
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("autoFullscreenOnOpen") private var autoFullscreenOnOpen: Bool = false
  #if os(iOS)
    @AppStorage("autoHideControls") private var autoHideControls: Bool = false
  #endif
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("shakeToOpenLiveText") private var shakeToOpenLiveText: Bool = false

  var body: some View {
    SheetView(
      title: String(localized: "Reader Settings"), size: .large, applyFormStyle: true
    ) {
      Form {
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

          #if os(iOS)
            Toggle(isOn: $autoHideControls) {
              Text("Auto Hide Controls")
            }
          #endif

        }

        #if !os(tvOS)
          Section(header: Text("Live Text")) {
            Toggle(isOn: $enableLiveText) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Enable Live Text")
                Text("Automatically enable Live Text for all images.")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            #if os(iOS)
              Toggle(isOn: $shakeToOpenLiveText) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Shake to Open Live Text")
                  Text("Shake your device to toggle Live Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            #endif
          }
        #endif

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
            Picker("Tap Zone Mode", selection: $tapZoneMode) {
              ForEach(TapZoneMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
            .pickerStyle(.menu)

            if !tapZoneMode.isDisabled {
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

                HStack(spacing: 12) {
                  switch tapZoneMode {
                  case .none:
                    EmptyView()
                  case .auto:
                    TapZonePreview(size: tapZoneSize, direction: readingDirection)
                  case .ltr:
                    TapZonePreview(size: tapZoneSize, direction: .ltr)
                  case .rtl:
                    TapZonePreview(size: tapZoneSize, direction: .rtl)
                  case .vertical:
                    TapZonePreview(size: tapZoneSize, direction: .vertical)
                  case .webtoon:
                    TapZonePreview(size: tapZoneSize, direction: .webtoon)
                  }
                }
                .frame(height: 60)
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
    .animation(.default, value: tapZoneMode)
    .presentationDragIndicator(.visible)
  }
}
