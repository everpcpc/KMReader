//
//  EpubPreferencesView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import CoreText
  import Foundation
  import SwiftData
  import SwiftUI
  import UIKit
  import WebKit

  struct EpubPreferencesView: View {
    let inSheet: Bool
    let bookId: String?
    let hasBookPreferences: Bool
    let onPreferencesSaved: ((EpubReaderPreferences) -> Void)?
    let onPreferencesCleared: (() -> Void)?

    private let baselinePreferences: EpubReaderPreferences
    @State private var draft: EpubReaderPreferences
    @State private var showCustomFontsSheet: Bool = false
    @State private var showPresetsSheet: Bool = false
    @State private var showSavePresetAlert: Bool = false
    @State private var newPresetName: String = ""
    @State private var fontListRefreshId: UUID = UUID()

    @AppStorage("epubPageTransitionStyle") private var epubPageTransitionStyle: PageTransitionStyle = .scroll

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomFont.name, order: .forward) private var customFonts: [CustomFont]

    init(
      inSheet: Bool = false,
      bookId: String? = nil,
      hasBookPreferences: Bool = false,
      initialPreferences: EpubReaderPreferences? = nil,
      onPreferencesSaved: ((EpubReaderPreferences) -> Void)? = nil,
      onPreferencesCleared: (() -> Void)? = nil
    ) {
      self.inSheet = inSheet
      self.bookId = bookId
      self.hasBookPreferences = hasBookPreferences
      self.onPreferencesSaved = onPreferencesSaved
      self.onPreferencesCleared = onPreferencesCleared
      let baseline = initialPreferences ?? AppConfig.epubPreferences
      self.baselinePreferences = baseline
      self._draft = State(initialValue: baseline)
    }

    private var isBookContext: Bool {
      bookId != nil
    }

    private var navigationTitle: String {
      if isBookContext {
        return String(localized: "Current Book")
      }
      return SettingsSection.epubReader.title
    }

    private var shouldShowResetToGlobal: Bool {
      isBookContext && hasBookPreferences
    }

    private var isSaveDisabled: Bool {
      draft == baselinePreferences
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

    private var fontWeightEnabled: Binding<Bool> {
      Binding(
        get: { draft.fontWeight != nil },
        set: { isOn in
          if isOn {
            if draft.fontWeight == nil {
              draft.fontWeight = EpubConstants.defaultFontWeight
            }
          } else {
            draft.fontWeight = nil
          }
        }
      )
    }

    private var fontWeightValue: Binding<Double> {
      Binding(
        get: { draft.fontWeight ?? EpubConstants.defaultFontWeight },
        set: { draft.fontWeight = $0 }
      )
    }

    private var fontWeightLabelText: String {
      let valueText: String
      if let fontWeight = draft.fontWeight {
        valueText = String(format: "%.1f", fontWeight)
      } else {
        valueText = String(localized: "Default")
      }
      return String.localizedStringWithFormat(String(localized: "Weight: %@"), valueText)
    }

    private var themePicker: some View {
      let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
      ]

      return LazyVGrid(columns: columns, spacing: 12) {
        ForEach(ThemeChoice.allCases) { choice in
          themePreviewButton(for: choice)
        }
      }
      .padding(.vertical, 4)
    }

    @ViewBuilder
    private func themePreviewButton(for choice: ThemeChoice) -> some View {
      let previewTheme = choice.resolvedTheme(for: colorScheme)
      let isSelected = draft.theme == choice

      Button {
        draft.theme = choice
      } label: {
        Image(systemName: "textformat")
          .font(.system(size: 20))
          .foregroundStyle(previewTheme.textColor)
          .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
          .padding(8)
          .background(previewTheme.backgroundColor)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var body: some View {
      Form {
        Section(String(localized: "Page Turn")) {
          Picker(String(localized: "Page Transition Style"), selection: $epubPageTransitionStyle) {
            ForEach(PageTransitionStyle.availableCases, id: \.self) { style in
              Text(style.displayName).tag(style)
            }
          }
          .pickerStyle(.menu)
        }

        Section(String(localized: "Presets")) {
          Button {
            showPresetsSheet = true
          } label: {
            HStack {
              Label(String(localized: "Load Preset"), systemImage: "bookmark")
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
            }
          }

          Button {
            showSavePresetAlert = true
          } label: {
            Label(String(localized: "Save as Preset"), systemImage: "bookmark.fill")
          }
        }

        Section(String(localized: "Theme")) {
          themePicker
        }

        Section(String(localized: "Font")) {
          Picker(String(localized: "Typeface"), selection: $draft.fontFamily) {
            ForEach(FontProvider.allChoices, id: \.id) { choice in
              Text(choice.rawValue).tag(choice)
            }
          }
          .id(fontListRefreshId)

          HStack {
            Text(fontWeightLabelText)
            Spacer()
            Toggle("", isOn: fontWeightEnabled)
              .labelsHidden()
          }

          if draft.fontWeight != nil {
            Slider(value: fontWeightValue, in: 0.0...5.0, step: 0.1)
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

        Section(String(localized: "Page")) {
          Picker(String(localized: "Page Layout"), selection: $draft.columnCount) {
            ForEach(EpubColumnCount.allCases) { option in
              Text(option.label)
                .tag(option)
            }
          }
          .pickerStyle(.segmented)

          VStack(alignment: .leading) {
            Slider(value: $draft.pageMargins, in: 0.25...2.0, step: 0.05)
            Text(
              String(localized: "Page Margins: \(String(format: "%.2f", draft.pageMargins))x")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }

        Section {
          Toggle(String(localized: "Advanced Layout"), isOn: $draft.advancedLayout)
        }

        if draft.advancedLayout {
          Section(String(localized: "Character & Word")) {
            VStack(alignment: .leading) {
              Slider(value: $draft.fontSize, in: 0.25...4.0, step: 0.05)
              Text(String(localized: "Font Size: \(String(format: "%.2f", draft.fontSize))x"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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
        }
      }
      .formStyle(.grouped)
      .animation(.easeInOut(duration: 0.2), value: draft.advancedLayout)
      .animation(.easeInOut(duration: 0.2), value: draft.fontWeight != nil)
      .onChange(of: draft.advancedLayout) {
        draft.fontSize = EpubConstants.defaultFontScale
        draft.wordSpacing = EpubConstants.defaultWordSpacing
        draft.paragraphSpacing = EpubConstants.defaultParagraphSpacing
        draft.paragraphIndent = EpubConstants.defaultParagraphIndent
        draft.letterSpacing = EpubConstants.defaultLetterSpacing
        draft.lineHeight = EpubConstants.defaultLineHeight
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        EpubPreviewView(preferences: draft)
          .frame(height: 160)
          .background(backgroundColor)
          .overlay(alignment: .bottom) {
            LinearGradient(
              colors: [
                backgroundColor,
                backgroundColor.opacity(0),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
            .frame(height: 20)
            .offset(y: 20)
            .allowsHitTesting(false)
          }
      }
      .toolbar {
        ToolbarItemGroup(placement: .cancellationAction) {
          if inSheet {
            Button {
              dismiss()
            } label: {
              Label(String(localized: "Close"), systemImage: "xmark")
            }
          }
          Button {
            draft = EpubReaderPreferences()
            ErrorManager.shared.notify(message: String(localized: "Reset"))
          } label: {
            Label(String(localized: "Reset"), systemImage: "arrow.counterclockwise")
          }
        }
        ToolbarItemGroup(placement: .confirmationAction) {
          if shouldShowResetToGlobal {
            Button {
              clearBookPreferences()
            } label: {
              Label(String(localized: "Reset to Global"), systemImage: "trash")
            }
          }
          Button {
            savePreferences()
          } label: {
            Label(String(localized: "Done"), systemImage: "checkmark")
          }
          .disabled(isSaveDisabled)
        }
      }
      .inlineNavigationBarTitle(navigationTitle)
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
      .sheet(isPresented: $showPresetsSheet) {
        EpubThemePresetsView(onApply: { preferences in
          draft = preferences
          if !isBookContext {
            AppConfig.epubPreferences = preferences
          }
        })
      }
      .alert(
        "Save Preset",
        isPresented: $showSavePresetAlert
      ) {
        TextField("Preset Name", text: $newPresetName)
        Button("Cancel", role: .cancel) {
          newPresetName = ""
        }
        Button("Save") {
          savePreset()
        }
      } message: {
        Text("Enter a name for this theme preset")
      }
    }

    private func savePreset() {
      let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { return }

      let preset = EpubThemePreset.create(
        name: trimmed,
        preferences: draft
      )
      modelContext.insert(preset)
      try? modelContext.save()

      ErrorManager.shared.notify(message: String(localized: "Preset saved: \(trimmed)"))
      newPresetName = ""
    }

    private func savePreferences() {
      if let bookId {
        Task {
          await DatabaseOperator.shared.updateBookEpubPreferences(
            bookId: bookId,
            preferences: draft
          )
          await DatabaseOperator.shared.commit()
        }
        onPreferencesSaved?(draft)
        dismiss()
        return
      }

      AppConfig.epubPreferences = draft
      dismiss()
    }

    private func clearBookPreferences() {
      guard let bookId else { return }
      Task {
        await DatabaseOperator.shared.updateBookEpubPreferences(
          bookId: bookId,
          preferences: nil
        )
        await DatabaseOperator.shared.commit()
      }
      onPreferencesCleared?()
      ErrorManager.shared.notify(message: String(localized: "Reset to Global"))
      dismiss()
    }
  }

  struct EpubPreviewView: View {
    let preferences: EpubReaderPreferences
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \CustomFont.name, order: .forward) private var customFonts: [CustomFont]

    private var customFontPath: String? {
      guard case .system(let fontName) = preferences.fontFamily else { return nil }
      guard let relativePath = customFonts.first(where: { $0.name == fontName })?.path else {
        return nil
      }
      return FontFileManager.resolvePath(relativePath)
    }

    var body: some View {
      WebViewRepresentable(
        preferences: preferences,
        colorScheme: colorScheme,
        customFontPath: customFontPath
      )
    }
  }

  private struct WebViewRepresentable: UIViewRepresentable {
    let preferences: EpubReaderPreferences
    let colorScheme: ColorScheme
    let customFontPath: String?

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.isScrollEnabled = false
      webView.navigationDelegate = context.coordinator
      context.coordinator.loadBaseHTMLIfNeeded(in: webView)
      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
      context.coordinator.update(
        webView: webView,
        preferences: preferences,
        colorScheme: colorScheme,
        customFontPath: customFontPath
      )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
      private var isLoaded = false
      private var previewURL: URL?
      private var lastAppliedPayload: PreviewPayload?
      private var pendingPayload: PreviewPayload?

      func loadBaseHTMLIfNeeded(in webView: WKWebView) {
        guard let previewURL = preparePreviewFile() else { return }
        if webView.url?.standardizedFileURL != previewURL.standardizedFileURL {
          isLoaded = false
          webView.loadFileURL(
            previewURL,
            allowingReadAccessTo: previewURL.deletingLastPathComponent()
          )
        }
      }

      func update(
        webView: WKWebView,
        preferences: EpubReaderPreferences,
        colorScheme: ColorScheme,
        customFontPath: String?
      ) {
        pendingPayload = makePreviewPayload(
          preferences: preferences,
          colorScheme: colorScheme,
          customFontPath: customFontPath
        )
        loadBaseHTMLIfNeeded(in: webView)
        applyPendingPayloadIfPossible(in: webView)
      }

      func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        applyPendingPayloadIfPossible(in: webView)
      }

      private func applyPendingPayloadIfPossible(in webView: WKWebView) {
        guard isLoaded, let payload = pendingPayload else { return }
        if lastAppliedPayload == payload { return }
        guard let payloadJSON = encodePreviewPayload(payload) else { return }

        let js = """
          (function() {
            var payload = \(payloadJSON);
            var root = document.documentElement;
            var body = document.body;
            if (!root || !body) { return false; }

            if (payload.lang) {
              root.setAttribute('lang', payload.lang);
              body.setAttribute('lang', payload.lang);
            }

            if (payload.dir) {
              root.setAttribute('dir', payload.dir);
              body.setAttribute('dir', payload.dir);
            } else {
              root.removeAttribute('dir');
              body.removeAttribute('dir');
            }

            var style = document.getElementById('kmreader-preview-style');
            if (!style) {
              style = document.createElement('style');
              style.id = 'kmreader-preview-style';
              document.head.appendChild(style);
            }
            style.textContent = payload.css || '';

            var p1 = document.getElementById('kmreader-preview-1');
            var p2 = document.getElementById('kmreader-preview-2');
            var p3 = document.getElementById('kmreader-preview-3');
            if (p1) { p1.textContent = payload.text1 || ''; }
            if (p2) { p2.textContent = payload.text2 || ''; }
            if (p3) { p3.textContent = payload.text3 || ''; }
            return true;
          })();
          """

        webView.evaluateJavaScript(js) { [weak self] _, _ in
          self?.lastAppliedPayload = payload
        }
      }

      private func preparePreviewFile() -> URL? {
        let directory = FontFileManager.fontsDirectory() ?? FileManager.default.temporaryDirectory
        let previewURL = directory.appendingPathComponent("preview.html")
        if previewURL == self.previewURL, FileManager.default.fileExists(atPath: previewURL.path) {
          return previewURL
        }

        let html = basePreviewHTML()
        guard let data = html.data(using: .utf8) else { return nil }
        do {
          try data.write(to: previewURL, options: [.atomic])
          self.previewURL = previewURL
          return previewURL
        } catch {
          return nil
        }
      }
    }
  }

  private struct PreviewPayload: Equatable {
    let css: String
    let text1: String
    let text2: String
    let text3: String
    let language: String
    let direction: String?
  }

  private func basePreviewHTML() -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style id="kmreader-preview-style"></style>
    </head>
    <body>
      <p id="kmreader-preview-1"></p>
      <p id="kmreader-preview-2"></p>
      <p id="kmreader-preview-3"></p>
    </body>
    </html>
    """
  }

  private func makePreviewPayload(
    preferences: EpubReaderPreferences,
    colorScheme: ColorScheme,
    customFontPath: String?
  ) -> PreviewPayload {
    let theme = preferences.resolvedTheme(for: colorScheme)
    let backgroundColor = theme.backgroundColorHex
    let textColor = theme.textColorHex

    let useAdvancedLayout = preferences.advancedLayout
    let fontScale = useAdvancedLayout ? preferences.fontSize : EpubConstants.defaultFontScale
    let fontSize = fontScale * 100
    let fontFamily =
      preferences.fontFamily.fontName.map { "'\($0)'" } ?? "system-ui, -apple-system, sans-serif"

    // Calculate font weight (0.0 to 5.0 maps to 240 to 960)
    let fontWeightValue = preferences.fontWeight.map { 240 + Int($0 * 160) }
    let letterSpacingEm =
      useAdvancedLayout ? preferences.letterSpacing : EpubConstants.defaultLetterSpacing
    let wordSpacingEm =
      useAdvancedLayout ? preferences.wordSpacing : EpubConstants.defaultWordSpacing
    let lineHeightValue =
      useAdvancedLayout ? preferences.lineHeight : EpubConstants.defaultLineHeight
    let paragraphSpacingEm =
      useAdvancedLayout ? preferences.paragraphSpacing : EpubConstants.defaultParagraphSpacing
    let paragraphIndentEm =
      useAdvancedLayout ? preferences.paragraphIndent : EpubConstants.defaultParagraphIndent

    let internalPadding = Int(round(max(0, preferences.pageMargins) * 20.0))

    var fontFaceCSS = ""
    if let fontName = preferences.fontFamily.fontName, let path = customFontPath {
      let fontURL = URL(fileURLWithPath: path)
      let fontFormat = path.hasSuffix(".otf") ? "opentype" : "truetype"
      fontFaceCSS = """
        @font-face {
          font-family: '\(fontName)';
          src: url('\(fontURL.absoluteString)') format('\(fontFormat)');
        }

        """
    }

    let language = Locale.current.identifier
    let languageCode = Locale.current.language.languageCode?.identifier ?? language
    let direction: String? =
      Locale.Language(identifier: languageCode).characterDirection == .rightToLeft
      ? "rtl"
      : nil

    let previewText1 = String(
      localized:
        "The quick brown fox jumps over the lazy dog. This is a sample text to preview your reading preferences.")
    let previewText2 = String(
      localized:
        "You can adjust the font size, spacing, and other settings to find what works best for you. Each paragraph demonstrates how the text will appear with your current choices."
    )
    let previewText3 = String(
      localized:
        "Reading should be comfortable and enjoyable. Take your time to customize these settings until you find the perfect combination."
    )

    let css = """
      \(fontFaceCSS)body {
        padding: \(internalPadding)px;
        margin: 0;
        background-color: \(backgroundColor);
        color: \(textColor);
        font-family: \(fontFamily);
        font-size: \(fontSize)%;
        \(fontWeightValue.map { "font-weight: \($0);" } ?? "")
        letter-spacing: \(letterSpacingEm)em;
        word-spacing: \(wordSpacingEm)em;
        line-height: \(lineHeightValue);
      }
      p {
        margin: 0;
        margin-bottom: \(max(0, paragraphSpacingEm))em;
        text-indent: \(max(0, paragraphIndentEm))em;
      }
      """

    return PreviewPayload(
      css: css,
      text1: previewText1,
      text2: previewText2,
      text3: previewText3,
      language: language,
      direction: direction
    )
  }

  private func encodePreviewPayload(_ payload: PreviewPayload) -> String? {
    let dict: [String: Any] = [
      "css": payload.css,
      "text1": payload.text1,
      "text2": payload.text2,
      "text3": payload.text3,
      "lang": payload.language,
      "dir": payload.direction ?? NSNull(),
    ]
    guard
      let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
      let json = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return json
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
