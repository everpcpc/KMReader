//
// EpubPreferencesView.swift
//
//

#if os(iOS)
  import Foundation
  import SwiftData
  import SwiftUI

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
    @AppStorage("epubShowsStatusBarWhileReading") private var epubShowsStatusBarWhileReading: Bool = false
    @AppStorage("epubShowsProgressFooter") private var epubShowsProgressFooter: Bool = false

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
        valueText = "\(Int(fontWeight.rounded()))"
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
          Picker(String(localized: "epub.reading_flow"), selection: $draft.flowStyle) {
            ForEach(EpubFlowStyle.allCases) { style in
              Text(style.displayName).tag(style)
            }
          }
          .pickerStyle(.menu)

          if draft.flowStyle.isPaged {
            Picker(String(localized: "Page Transition Style"), selection: $epubPageTransitionStyle) {
              ForEach(PageTransitionStyle.epubAvailableCases, id: \.self) { style in
                Text(style.displayName).tag(style)
              }
            }
            .pickerStyle(.menu)

            Text(epubPageTransitionStyle.description)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section(String(localized: "Reader Overlay")) {
          Toggle(isOn: $epubShowsStatusBarWhileReading) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "Show Status Bar While Reading"))
              Text(String(localized: "Keep time and battery visible when controls are hidden."))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Toggle(isOn: $epubShowsProgressFooter) {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "Show Progress Footer"))
              Text(String(localized: "Show book progress at the bottom while reading."))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
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
              Text(choice.displayName).tag(choice)
            }
          }
          .id(fontListRefreshId)

          HStack {
            Text(fontWeightLabelText)
            Spacer()
            Toggle("", isOn: fontWeightEnabled)
              .labelsHidden()
          }

          Text(
            String(
              localized:
                "Font weight support depends on the current font. Some fonts may ignore this setting or only support part of the range."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)

          if draft.fontWeight != nil {
            Slider(
              value: fontWeightValue,
              in: EpubConstants.minimumFontWeight...EpubConstants.maximumFontWeight,
              step: EpubConstants.fontWeightStep
            )
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
          if draft.flowStyle.isPaged {
            Picker(String(localized: "Page Layout"), selection: $draft.columnCount) {
              ForEach(EpubColumnCount.allCases) { option in
                Text(option.label)
                  .tag(option)
              }
            }
            .pickerStyle(.segmented)
          }

          if draft.flowStyle == .scrolled {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(String(localized: "epub.scrolled.tap_scroll_height"))
                Spacer()
                Text("\(Int(draft.tapScrollPercentage))%")
                  .foregroundStyle(.secondary)
              }
              Slider(
                value: $draft.tapScrollPercentage,
                in: 25...100,
                step: 5
              )
              Text(String(localized: "epub.scrolled.tap_scroll_height.description"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

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
            Picker(
              String(localized: "epub.text_alignment.title", defaultValue: "Text Alignment"),
              selection: $draft.textAlignment
            ) {
              ForEach(EpubTextAlignment.allCases) { alignment in
                Text(alignment.displayName)
                  .tag(alignment)
              }
            }
            .pickerStyle(.menu)

            Text(
              String(
                localized: "epub.text_alignment.justify.description",
                defaultValue: "Justify automatically enables hyphenation."
              )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

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
      .animation(.easeInOut(duration: 0.2), value: draft.flowStyle)
      .onChange(of: draft.advancedLayout) {
        draft.fontSize = EpubConstants.defaultFontScale
        draft.wordSpacing = EpubConstants.defaultWordSpacing
        draft.paragraphSpacing = EpubConstants.defaultParagraphSpacing
        draft.paragraphIndent = EpubConstants.defaultParagraphIndent
        draft.letterSpacing = EpubConstants.defaultLetterSpacing
        draft.lineHeight = EpubConstants.defaultLineHeight
        draft.textAlignment = .publisherDefault
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        EpubSettingsPreviewView(preferences: draft)
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
            if let selectedFontName = draft.fontFamily.fontName {
              let isKnownCustomFont = customFontNames.contains(selectedFontName)
              let isKnownChoice = FontProvider.allChoices.contains(where: {
                $0.fontName == selectedFontName
              })
              if !isKnownCustomFont && !isKnownChoice {
                draft.fontFamily = .publisher
              }
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
          try? await DatabaseOperator.database().updateBookEpubPreferences(
            bookId: bookId,
            preferences: draft
          )
          try? await DatabaseOperator.database().commit()
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
        try? await DatabaseOperator.database().updateBookEpubPreferences(
          bookId: bookId,
          preferences: nil
        )
        try? await DatabaseOperator.database().commit()
      }
      onPreferencesCleared?()
      ErrorManager.shared.notify(message: String(localized: "Reset to Global"))
      dismiss()
    }
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
