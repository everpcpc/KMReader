//
//  SettingsReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsReaderView: View {
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("autoFullscreenOnOpen") private var autoFullscreenOnOpen: Bool = false
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("pageLayout") private var pageLayout: PageLayout = .auto
  @AppStorage("isolateCoverPage") private var isolateCoverPage: Bool = true
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("webtoonTapScrollPercentage") private var webtoonTapScrollPercentage: Double = 80.0
  @AppStorage("defaultReadingDirection") private var readDirection: ReadingDirection = .ltr
  @AppStorage("forceDefaultReadingDirection") private var forceDefaultReadingDirection: Bool = false
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("autoHideControls") private var autoHideControls: Bool = false
  @AppStorage("tapPageTransitionDuration") private var tapPageTransitionDuration: Double = 0.2
  @AppStorage("pageTransitionStyle") private var pageTransitionStyle: PageTransitionStyle = .scroll
  @AppStorage("scrollPageTransitionStyle") private var scrollPageTransitionStyle: ScrollPageTransitionStyle = .default
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0
  @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("shakeToOpenLiveText") private var shakeToOpenLiveText: Bool = false

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

        Toggle(isOn: $showPageNumber) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Always Show Page Number")
            Text("Display page number overlay on images while reading")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        #if os(iOS)
          Toggle(isOn: $autoHideControls) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Auto Hide Controls")
              Text("Automatically hide reader controls after a short delay")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #endif

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

        #if os(macOS)
          Toggle(isOn: $autoFullscreenOnOpen) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Auto Full Screen on Open")
              Text("Automatically enter full screen when opening the reader")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        #endif
      }

      #if os(iOS)
        Section(header: Text("Zooming")) {
          Picker("Double Tap to Zoom", selection: $doubleTapZoomMode) {
            ForEach(DoubleTapZoomMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.menu)
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
        }
      #endif

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

      Section(header: Text("Page Turn")) {
        #if os(iOS)
          VStack(alignment: .leading, spacing: 8) {
            Picker("Page Transition Style", selection: $pageTransitionStyle) {
              ForEach(PageTransitionStyle.availableCases, id: \.self) { style in
                Text(style.displayName).tag(style)
              }
            }
            .pickerStyle(.menu)
            Text(pageTransitionStyle.description)
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

        #if os(iOS) || os(macOS)
          VStack(alignment: .leading, spacing: 8) {
            Picker("Tap Zone Mode", selection: $tapZoneMode) {
              ForEach(TapZoneMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
            .pickerStyle(.menu)
            Text("Choose how tap zones work: auto matches reading direction, or select a fixed layout")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          if !tapZoneMode.isDisabled {
            Toggle(isOn: $showTapZoneHints) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Show Tap Zone Hints")
                Text("Display tap zone hints when opening the reader")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
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
                  TapZonePreview(size: tapZoneSize, direction: .ltr)
                  TapZonePreview(size: tapZoneSize, direction: .rtl)
                  TapZonePreview(size: tapZoneSize, direction: .vertical)
                  TapZonePreview(size: tapZoneSize, direction: .webtoon)
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
              .frame(height: 80)

              Text("Size of tap zones for page navigation")
                .font(.caption)
                .foregroundColor(.secondary)
            }

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
              Text("Animation duration when tap to turn pages")
                .font(.caption)
                .foregroundColor(.secondary)
            }

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

        Toggle(isOn: $forceDefaultReadingDirection) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Force Default Reading Direction")
            Text("Ignore book and series metadata and always use the preferred direction")
              .font(.caption)
              .foregroundColor(.secondary)
          }
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
          Toggle(isOn: $isolateCoverPage) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Isolate Cover Page")
              Text("Display the cover page separately, not paired with the next page")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .animation(.default, value: tapZoneMode)
    .formStyle(.grouped)
    .inlineNavigationBarTitle(SettingsSection.reader.title)
  }
}
