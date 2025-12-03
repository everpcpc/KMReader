//
//  EpubPreferencesSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import CoreText
  import ReadiumNavigator
  import SwiftData
  import SwiftUI
  import UIKit
  import WebKit

  struct EpubPreferencesSheet: View {
    let onApply: (EpubReaderPreferences) -> Void
    @State private var draft: EpubReaderPreferences
    @State private var showCustomFontsSheet: Bool = false
    @State private var fontListRefreshId: UUID = UUID()

    @Query(sort: \CustomFont.name, order: .forward) private var customFonts: [CustomFont]
    @Environment(\.dismiss) private var dismiss

    init(_ pref: EpubReaderPreferences, onApply: @escaping (EpubReaderPreferences) -> Void) {
      self._draft = State(initialValue: pref)
      self.onApply = onApply
    }

    var body: some View {
      SheetView(title: "Reading Options", size: .large) {
        VStack(spacing: 0) {
          VStack(alignment: .leading, spacing: 8) {
            EpubPreviewView(preferences: draft)
              .frame(height: 200)
              .cornerRadius(8)
          }
          .padding(.horizontal, 16)
          .padding(.vertical)
          .background(Color(uiColor: .systemGroupedBackground))

          Form {
            Section("Theme") {
              Picker("Appearance", selection: $draft.theme) {
                ForEach(ThemeChoice.allCases) { choice in
                  Text(choice.title).tag(choice)
                }
              }
              .pickerStyle(.segmented)
            }

            Section("Pagination") {
              Picker("Reading Mode", selection: $draft.pagination) {
                ForEach(PaginationMode.allCases) { mode in
                  Label(mode.title, systemImage: mode.icon).tag(mode)
                }
              }
              Picker("Page Layout", selection: $draft.layout) {
                ForEach(LayoutChoice.allCases) { layout in
                  Label(layout.title, systemImage: layout.icon).tag(layout)
                }
              }
            }

            Section("Font") {
              Picker("Typeface", selection: $draft.fontFamily) {
                ForEach(FontProvider.allChoices, id: \.id) { choice in
                  Text(choice.rawValue).tag(choice)
                }
              }
              .id(fontListRefreshId)
              VStack(alignment: .leading) {
                Slider(value: $draft.fontSize, in: 0.5...2.0, step: 0.05)
                Text("Size: \(String(format: "%.2f", draft.fontSize))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading) {
                Slider(value: $draft.fontWeight, in: 0.0...2.5, step: 0.1)
                Text("Weight: \(String(format: "%.1f", draft.fontWeight))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Button {
                showCustomFontsSheet = true
              } label: {
                HStack {
                  Label("Manage Custom Fonts", systemImage: "textformat")
                  Spacer()
                  if !customFonts.isEmpty {
                    Text("\(customFonts.count)")
                      .foregroundStyle(.secondary)
                  }
                  Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                }
              }
            }

            Section("Character & Word") {
              VStack(alignment: .leading) {
                Slider(value: $draft.letterSpacing, in: 0.0...2.0, step: 0.1)
                Text("Letter Spacing: \(String(format: "%.1f", draft.letterSpacing))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading) {
                Slider(value: $draft.wordSpacing, in: 0.0...3.0, step: 0.1)
                Text("Word Spacing: \(String(format: "%.1f", draft.wordSpacing))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            Section("Line & Paragraph") {
              VStack(alignment: .leading) {
                Slider(value: $draft.lineHeight, in: 0.5...3.0, step: 0.1)
                Text("Line Height: \(String(format: "%.1f", draft.lineHeight))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading) {
                Slider(value: $draft.paragraphSpacing, in: 0.0...3.0, step: 0.1)
                Text("Paragraph Spacing: \(String(format: "%.1f", draft.paragraphSpacing))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading) {
                Slider(value: $draft.paragraphIndent, in: 0.0...2.0, step: 0.1)
                Text("Paragraph Indent: \(String(format: "%.1f", draft.paragraphIndent))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            Section("Page Layout") {
              VStack(alignment: .leading) {
                Slider(value: $draft.pageMargins, in: 0.0...2.0, step: 0.1)
                Text("Page Margins: \(String(format: "%.1f", draft.pageMargins))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      } controls: {
        Button {
          onApply(draft)
          dismiss()
        } label: {
          Label("Save", systemImage: "checkmark")
        }
      }
      .sheet(isPresented: $showCustomFontsSheet) {
        CustomFontsSheet()
          .onDisappear {
            FontProvider.refresh()
            fontListRefreshId = UUID()

            let customFontNames = customFonts.map { $0.name }
            if !customFontNames.contains(draft.fontFamily.rawValue)
              && draft.fontFamily != .publisher
              && !FontProvider.allChoices.contains(where: {
                $0.rawValue == draft.fontFamily.rawValue
              })
            {
              draft.fontFamily = .publisher
            }
          }
      }
    }
  }

  struct EpubPreviewView: View {
    let preferences: EpubReaderPreferences

    var body: some View {
      WebViewRepresentable(preferences: preferences)
    }
  }

  private struct WebViewRepresentable: UIViewRepresentable {
    let preferences: EpubReaderPreferences

    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.isScrollEnabled = false
      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
      let html = generatePreviewHTML(preferences: preferences)
      webView.loadHTMLString(html, baseURL: nil)
    }
  }

  private func generatePreviewHTML(preferences: EpubReaderPreferences) -> String {
    let theme = preferences.theme.resolvedTheme(for: nil) ?? .light
    let backgroundColor: String
    let textColor: String

    switch theme {
    case .light:
      backgroundColor = "#FFFFFF"
      textColor = "#000000"
    case .sepia:
      backgroundColor = "#F4ECD8"
      textColor = "#5C4A37"
    case .dark:
      backgroundColor = "#1E1E1E"
      textColor = "#E0E0E0"
    }

    let baseFontSize = 16.0
    let fontSize = baseFontSize * preferences.fontSize
    let fontFamily =
      preferences.fontFamily.fontFamily?.rawValue ?? "system-ui, -apple-system, sans-serif"

    // Calculate font weight (0.0 to 2.5 maps to 300 to 700)
    let fontWeightValue = 300 + Int(preferences.fontWeight * 160)

    let letterSpacingEm = (preferences.letterSpacing - 1.0) * 0.1
    let wordSpacingEm = (preferences.wordSpacing - 1.0) * 0.1
    let lineHeightValue = preferences.lineHeight
    let paragraphSpacingEm = (preferences.paragraphSpacing - 1.0) * 0.5
    let paragraphIndentEm = (preferences.paragraphIndent - 1.0) * 1.0
    let pageMarginEm = (preferences.pageMargins - 1.0) * 0.5

    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: \(max(0.5, pageMarginEm + 0.5))em;
            background-color: \(backgroundColor);
            color: \(textColor);
            font-family: \(fontFamily);
            font-size: \(fontSize)px;
            font-weight: \(fontWeightValue);
            letter-spacing: \(letterSpacingEm)em;
            word-spacing: \(wordSpacingEm)em;
            line-height: \(lineHeightValue);
          }
          p {
            margin: 0;
            margin-bottom: \(max(0, paragraphSpacingEm))em;
            text-indent: \(max(0, paragraphIndentEm))em;
          }
          p:first-child {
            text-indent: 0;
          }
        </style>
      </head>
      <body>
        <p>The quick brown fox jumps over the lazy dog. This is a sample text to preview your reading preferences.</p>
        <p>You can adjust the font size, spacing, and other settings to find what works best for you. Each paragraph demonstrates how the text will appear with your current choices.</p>
        <p>Reading should be comfortable and enjoyable. Take your time to customize these settings until you find the perfect combination.</p>
      </body>
      </html>
      """
  }

  enum FontProvider {
    private static var _allChoices: [FontFamilyChoice]?

    static var allChoices: [FontFamilyChoice] {
      if let cached = _allChoices {
        return cached
      }
      return loadFonts()
    }

    static func refresh() {
      _allChoices = nil
    }

    private static func loadFonts() -> [FontFamilyChoice] {
      // Only use custom fonts, not system fonts
      let customFonts = CustomFontStore.shared.fetchCustomFonts()
      let sorted = customFonts.sorted()
      let customChoices = sorted.map { FontFamilyChoice.system($0) }

      _allChoices = [.publisher] + customChoices
      return _allChoices!
    }
  }
#endif
