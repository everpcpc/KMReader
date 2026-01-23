//
//  EpubPreferencesSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import CoreText
  import SwiftData
  import SwiftUI
  import UIKit
  import WebKit

  struct EpubPreferencesSheet: View {
    let onApply: (EpubReaderPreferences) -> Void
    @State private var draft: EpubReaderPreferences
    @State private var showCustomFontsSheet: Bool = false
    @State private var fontListRefreshId: UUID = UUID()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @Query(sort: \CustomFont.name, order: .forward) private var customFonts: [CustomFont]

    init(_ pref: EpubReaderPreferences, onApply: @escaping (EpubReaderPreferences) -> Void) {
      self._draft = State(initialValue: pref)
      self.onApply = onApply
    }

    private var readerTheme: ReaderTheme {
      draft.theme.resolvedTheme(for: colorScheme)
    }

    private var backgroundColor: Color {
      Color(hex: readerTheme.backgroundColorHex) ?? .white
    }

    private var textColor: Color {
      Color(hex: readerTheme.textColorHex) ?? .primary
    }

    var body: some View {
      VStack(spacing: 0) {
        ZStack {
          EpubPreviewView(preferences: draft)

          VStack {
            HStack(spacing: 4) {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark")
                  .padding(4)
              }
              .contentShape(Circle())
              .buttonBorderShape(.circle)

              Button {
                draft = EpubReaderPreferences()
              } label: {
                Image(systemName: "arrow.counterclockwise")
                  .padding(2)
              }
              .contentShape(Circle())
              .buttonBorderShape(.circle)

              Spacer()

              Text(String(localized: "Reading Options"))
                .font(.headline)
                .foregroundStyle(textColor)

              Spacer()

              Button {
              } label: {
                Image(systemName: "checkmark")
                  .padding(4)
              }
              .opacity(0)
              .contentShape(Circle())
              .buttonBorderShape(.circle)
              .allowsHitTesting(false)

              Button {
                onApply(draft)
                dismiss()
              } label: {
                Image(systemName: "checkmark")
                  .padding(4)
              }
              .contentShape(Circle())
              .buttonBorderShape(.circle)
            }
            .adaptiveButtonStyle(.bordered)
            .padding(8)

            Spacer()
          }
          .background {
            LinearGradient(
              colors: [
                backgroundColor,
                backgroundColor,
                backgroundColor.opacity(0.5),
                Color.clear,
                Color.clear,
                Color.clear,
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          }

        }.frame(height: 240)

        Form {
          Section(String(localized: "Theme")) {
            Picker(String(localized: "Appearance"), selection: $draft.theme) {
              ForEach(ThemeChoice.allCases) { choice in
                Text(choice.title).tag(choice)
              }
            }
            .pickerStyle(.segmented)
          }

          Section(String(localized: "Font")) {
            Picker(String(localized: "Typeface"), selection: $draft.fontFamily) {
              ForEach(FontProvider.allChoices, id: \.id) { choice in
                Text(choice.rawValue).tag(choice)
              }
            }
            .id(fontListRefreshId)
            VStack(alignment: .leading) {
              Slider(value: $draft.fontSize, in: 8...32, step: 1)
              Text(String(localized: "Size: \(String(format: "%.0f", draft.fontSize))"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
              Slider(value: $draft.fontWeight, in: 0.0...2.5, step: 0.1)
              Text(String(localized: "Weight: \(String(format: "%.1f", draft.fontWeight))"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button {
              showCustomFontsSheet = true
            } label: {
              HStack {
                Label(String(localized: "Manage Custom Fonts"), systemImage: "textformat")
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

          Section(String(localized: "Character & Word")) {
            VStack(alignment: .leading) {
              Slider(value: $draft.letterSpacing, in: 0.00...1.0, step: 0.01)
              Text(
                String(
                  localized: "Letter Spacing: \(String(format: "%.2f", draft.letterSpacing))")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
              Slider(value: $draft.wordSpacing, in: 0.0...1.0, step: 0.01)
              Text(
                String(localized: "Word Spacing: \(String(format: "%.2f", draft.wordSpacing))")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }

          Section(String(localized: "Line & Paragraph")) {
            VStack(alignment: .leading) {
              Slider(value: $draft.lineHeight, in: 0.5...2.5, step: 0.1)
              Text(String(localized: "Line Height: \(String(format: "%.1f", draft.lineHeight))"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
              Slider(value: $draft.paragraphSpacing, in: 0.0...3.0, step: 0.1)
              Text(
                String(
                  localized:
                    "Paragraph Spacing: \(String(format: "%.1f", draft.paragraphSpacing))")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
              Slider(value: $draft.paragraphIndent, in: 0.0...8.0, step: 0.5)
              Text(
                String(
                  localized: "Paragraph Indent: \(String(format: "%.1f", draft.paragraphIndent))")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }

          Section(String(localized: "Page Layout")) {
            VStack(alignment: .leading) {
              Slider(value: $draft.pageMargins, in: 8.0...32.0, step: 1.0)
              Text(
                String(localized: "Page Margins: \(String(format: "%.0f", draft.pageMargins))px")
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
      WebViewRepresentable(preferences: preferences, colorScheme: colorScheme)
    }
  }

  private struct WebViewRepresentable: UIViewRepresentable {
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.isScrollEnabled = false
      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
      let html = generatePreviewHTML(preferences: preferences, colorScheme: colorScheme)
      webView.loadHTMLString(html, baseURL: nil)
    }
  }

  private func generatePreviewHTML(preferences: EpubReaderPreferences, colorScheme: ColorScheme) -> String {
    let theme = preferences.resolvedTheme(for: colorScheme)
    let backgroundColor = theme.backgroundColorHex
    let textColor = theme.textColorHex

    let fontSize = preferences.fontSize
    let fontFamily =
      preferences.fontFamily.fontName.map { "'\($0)'" } ?? "system-ui, -apple-system, sans-serif"

    // Calculate font weight (0.0 to 2.5 maps to 300 to 700)
    let fontWeightValue = 300 + Int(preferences.fontWeight * 160)
    let letterSpacingEm = preferences.letterSpacing
    let wordSpacingEm = preferences.wordSpacing
    let lineHeightValue = preferences.lineHeight
    let paragraphSpacingEm = preferences.paragraphSpacing
    let paragraphIndentEm = preferences.paragraphIndent

    // Use pixel-based padding in preview
    let internalPadding = Int(preferences.pageMargins)

    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            padding: \(internalPadding)px;
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
