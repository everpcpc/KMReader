//
// EpubReaderPreferences.swift
//
//

import Foundation
import SwiftUI

nonisolated enum EpubConstants {
  static let defaultFontScale: Double = 1.0

  static let defaultLetterSpacing: Double = 0.0
  static let defaultWordSpacing: Double = 0.0

  static let defaultLineHeight: Double = 1.2

  static let defaultParagraphSpacing: Double = 0.5
  static let defaultParagraphIndent: Double = 2.0

  static let defaultPageMargins: Double = 1.0

  static let defaultFontWeight: Double = 1.0
  static let defaultTapScrollPercentage: Double = 80.0
}

nonisolated struct EpubReaderPreferences: RawRepresentable, Equatable {
  typealias RawValue = String

  // Keep this list in sync with makeReadiumPayload.
  static let readiumPropertyKeys: [String] = [
    "--RS__textColor",
    "--RS__backgroundColor",
    "--USER__textColor",
    "--USER__backgroundColor",
    "--USER__linkColor",
    "--USER__visitedColor",
    "--RS__disableOverflow",
    "--USER__view",
    "--USER__iOSPatch",
    "--USER__iPadOSPatch",
    "--USER__blendImages",
    "--USER__fontOverride",
    "--USER__fontFamily",
    "--USER__fontWeightOverride",
    "--USER__fontWeight",
    "--USER__colCount",
    "--USER__lineLength",
    "--USER__fontSize",
    "--USER__lineHeight",
    "--USER__paraSpacing",
    "--USER__paraIndent",
    "--USER__wordSpacing",
    "--USER__letterSpacing",
  ]

  var theme: ThemeChoice
  var flowStyle: EpubFlowStyle
  var fontFamily: FontFamilyChoice
  var fontWeight: Double?
  var advancedLayout: Bool
  var fontSize: Double
  var wordSpacing: Double
  var paragraphSpacing: Double
  var paragraphIndent: Double
  var letterSpacing: Double
  var lineHeight: Double
  var columnCount: EpubColumnCount
  var pageMargins: Double
  var tapScrollPercentage: Double

  init(
    theme: ThemeChoice = .system,
    flowStyle: EpubFlowStyle = .paged,
    fontFamily: FontFamilyChoice = .publisher,
    fontWeight: Double? = nil,
    advancedLayout: Bool = false,
    fontSize: Double = EpubConstants.defaultFontScale,
    wordSpacing: Double = EpubConstants.defaultWordSpacing,
    paragraphSpacing: Double = EpubConstants.defaultParagraphSpacing,
    paragraphIndent: Double = EpubConstants.defaultParagraphIndent,
    letterSpacing: Double = EpubConstants.defaultLetterSpacing,
    lineHeight: Double = EpubConstants.defaultLineHeight,
    columnCount: EpubColumnCount = .auto,
    pageMargins: Double = EpubConstants.defaultPageMargins,
    tapScrollPercentage: Double = EpubConstants.defaultTapScrollPercentage,
  ) {
    self.theme = theme
    self.flowStyle = flowStyle
    self.fontFamily = fontFamily
    self.fontSize = fontSize
    self.wordSpacing = wordSpacing
    self.paragraphSpacing = paragraphSpacing
    self.paragraphIndent = paragraphIndent
    self.pageMargins = pageMargins
    self.columnCount = columnCount
    self.letterSpacing = letterSpacing
    self.lineHeight = lineHeight
    self.fontWeight = fontWeight
    self.advancedLayout = advancedLayout
    self.tapScrollPercentage = Self.normalizedTapScrollPercentage(tapScrollPercentage)
  }

  init?(rawValue: String) {
    guard !rawValue.isEmpty else {
      self.init()
      return
    }

    guard let data = rawValue.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      self.init()
      return
    }

    let theme = (dict["theme"] as? String).flatMap(ThemeChoice.init) ?? .system
    let flowStyleRaw = dict["flowStyle"] as? String ?? EpubFlowStyle.paged.rawValue
    let flowStyle = EpubFlowStyle(rawValue: flowStyleRaw) ?? .paged
    let fontString = dict["fontFamily"] as? String ?? FontFamilyChoice.publisher.rawValue
    let font = FontFamilyChoice(rawValue: fontString)
    let rawFontWeight = dict["fontWeight"] as? Double
    let fontWeight: Double? = {
      guard let rawFontWeight else { return nil }
      return rawFontWeight == EpubConstants.defaultFontWeight ? nil : rawFontWeight
    }()
    let advancedLayout = dict["advancedLayout"] as? Bool ?? false
    let fontSize = dict["fontSize"] as? Double ?? EpubConstants.defaultFontScale
    let wordSpacing = dict["wordSpacing"] as? Double ?? EpubConstants.defaultWordSpacing
    let paragraphSpacing = dict["paragraphSpacing"] as? Double ?? EpubConstants.defaultParagraphSpacing
    let paragraphIndent = dict["paragraphIndent"] as? Double ?? EpubConstants.defaultParagraphIndent
    let letterSpacing = dict["letterSpacing"] as? Double ?? EpubConstants.defaultLetterSpacing
    let lineHeight = dict["lineHeight"] as? Double ?? EpubConstants.defaultLineHeight
    let columnCountRaw = dict["columnCount"] as? String ?? EpubColumnCount.auto.rawValue
    let columnCount = EpubColumnCount(rawValue: columnCountRaw) ?? .auto
    let rawPageMargins = dict["pageMargins"] as? Double ?? EpubConstants.defaultPageMargins
    let pageMargins = Self.normalizedPageMargins(rawPageMargins)
    let rawTapScrollPercentage =
      dict["tapScrollPercentage"] as? Double ?? EpubConstants.defaultTapScrollPercentage
    let tapScrollPercentage = Self.normalizedTapScrollPercentage(rawTapScrollPercentage)

    self.init(
      theme: theme,
      flowStyle: flowStyle,
      fontFamily: font,
      fontWeight: fontWeight,
      advancedLayout: advancedLayout,
      fontSize: fontSize,
      wordSpacing: wordSpacing,
      paragraphSpacing: paragraphSpacing,
      paragraphIndent: paragraphIndent,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      columnCount: columnCount,
      pageMargins: pageMargins,
      tapScrollPercentage: tapScrollPercentage,
    )
  }

  var rawValue: String {
    var dict: [String: Any] = [
      "theme": theme.rawValue,
      "flowStyle": flowStyle.rawValue,
      "fontFamily": fontFamily.rawValue,
      "advancedLayout": advancedLayout,
      "fontSize": fontSize,
      "wordSpacing": wordSpacing,
      "paragraphSpacing": paragraphSpacing,
      "paragraphIndent": paragraphIndent,
      "letterSpacing": letterSpacing,
      "lineHeight": lineHeight,
      "columnCount": columnCount.rawValue,
      "pageMargins": pageMargins,
      "tapScrollPercentage": tapScrollPercentage,
    ]
    if let fontWeight {
      dict["fontWeight"] = fontWeight
    }
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  func resolvedTheme(for colorScheme: ColorScheme? = nil) -> ReaderTheme {
    theme.resolvedTheme(for: colorScheme)
  }

  func makeReadiumPayload(
    theme: ReaderTheme,
    fontPath: String? = nil,
    rootURL: URL? = nil,
    viewportSize: CGSize? = nil
  ) -> (css: String, properties: [String: String?]) {
    let fontName = fontFamily.fontName
    let darkLinkColors = darkThemeLinkColors

    var properties: [String: String?] = [
      "--RS__textColor": theme.textColorHex,
      "--RS__backgroundColor": theme.backgroundColorHex,
    ]
    properties["--USER__view"] = flowStyle == .scrolled ? "readium-scroll-on" : nil
    properties["--RS__disableOverflow"] =
      flowStyle == .scrolled ? "readium-noOverflow-on" : nil
    #if os(iOS)
      properties["--USER__iOSPatch"] = "readium-iOSPatch-on"
      properties["--USER__iPadOSPatch"] = nil
    #else
      properties["--USER__iOSPatch"] = nil
      properties["--USER__iPadOSPatch"] = nil
    #endif
    properties["font-weight"] = nil

    let fontFamilyValue = fontName.map(cssFontFamilyValue)
    properties["--USER__fontOverride"] = fontFamilyValue == nil ? nil : "readium-font-on"
    properties["--USER__fontFamily"] = fontFamilyValue
    if let fontWeight {
      let fontWeightValue = readiumFontWeightValue(for: fontWeight)
      properties["--USER__fontWeightOverride"] = "readium-font-weight-on"
      properties["--USER__fontWeight"] = "\(fontWeightValue)"
    } else {
      properties["--USER__fontWeightOverride"] = nil
      properties["--USER__fontWeight"] = nil
    }
    properties["--USER__colCount"] = resolvedReadiumColumnCount(for: viewportSize)
    properties["--USER__lineLength"] = readiumLineLengthValue(for: pageMargins)

    if theme.isDark {
      properties["--USER__textColor"] = theme.textColorHex
      properties["--USER__backgroundColor"] = theme.backgroundColorHex
      properties["--USER__linkColor"] = darkLinkColors.link
      properties["--USER__visitedColor"] = darkLinkColors.visited
    } else {
      properties["--USER__textColor"] = nil
      properties["--USER__backgroundColor"] = nil
      properties["--USER__linkColor"] = nil
      properties["--USER__visitedColor"] = nil
    }
    properties["--USER__blendImages"] =
      shouldUseLightImageBlend(for: theme)
      ? "readium-blend-on" : nil

    if advancedLayout {
      let fontSizePercent = fontSize * 100
      let letterSpacingRem = max(0, letterSpacing)
      let wordSpacingRem = max(0, wordSpacing)
      let paragraphSpacingRem = max(0, paragraphSpacing)
      let paragraphIndentRem = max(0, paragraphIndent)

      properties["--USER__fontSize"] = String(format: "%.2f%%", fontSizePercent)
      properties["--USER__lineHeight"] = String(format: "%.2f", lineHeight)
      properties["--USER__paraSpacing"] = String(format: "%.2frem", paragraphSpacingRem)
      properties["--USER__paraIndent"] = String(format: "%.2frem", paragraphIndentRem)
      properties["--USER__wordSpacing"] = String(format: "%.2frem", wordSpacingRem)
      properties["--USER__letterSpacing"] = String(format: "%.2frem", letterSpacingRem)
    } else {
      properties["--USER__fontSize"] = nil
      properties["--USER__lineHeight"] = nil
      properties["--USER__paraSpacing"] = nil
      properties["--USER__paraIndent"] = nil
      properties["--USER__wordSpacing"] = nil
      properties["--USER__letterSpacing"] = nil
    }

    let fontFaceCSS = makeFontFaceCSS(
      fontName: fontName,
      fontPath: fontPath,
      rootURL: rootURL
    )

    let fontWeightCSS = makeFontWeightCSS()
    let darkTextColorOverrideCSS = makeDarkTextColorOverrideCSS(theme: theme)
    let paginationCompatibilityCSS = makePaginationCompatibilityCSS()
    return (
      css: fontFaceCSS + fontWeightCSS + darkTextColorOverrideCSS + paginationCompatibilityCSS,
      properties: properties
    )
  }

  func makeCSS(
    theme: ReaderTheme,
    fontPath: String? = nil,
    rootURL: URL? = nil,
    viewportSize: CGSize? = nil
  ) -> String {
    makeReadiumPayload(
      theme: theme,
      fontPath: fontPath,
      rootURL: rootURL,
      viewportSize: viewportSize
    ).css
  }

  private func resolvedReadiumColumnCount(for viewportSize: CGSize?) -> String? {
    switch columnCount {
    case .one, .two:
      return columnCount.readiumValue
    case .auto:
      guard flowStyle == .paged else { return nil }
      guard let viewportSize else { return nil }
      let width = viewportSize.width
      return width >= 900 ? EpubColumnCount.two.readiumValue : EpubColumnCount.one.readiumValue
    }
  }

  private func readiumFontWeightValue(for weight: Double) -> Int {
    let rawValue = 240 + Int(weight * 160)
    return min(max(rawValue, 1), 1000)
  }

  private func cssFontFamilyValue(_ name: String) -> String {
    if name.contains("\"") || name.contains(" ") {
      return "\"" + name.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    return name
  }

  private func makeFontFaceCSS(fontName: String?, fontPath: String?, rootURL: URL?) -> String {
    guard let fontName, let path = fontPath, let rootURL else {
      return ""
    }

    let fileName = URL(fileURLWithPath: path).lastPathComponent
    let fontURL = rootURL.appendingPathComponent(".fonts").appendingPathComponent(fileName)
    let fileURLString = fontURL.absoluteString
    let fontFormat = path.hasSuffix(".otf") ? "opentype" : "truetype"

    return """
      @font-face {
        font-family: '\(fontName)';
        src: url('\(fileURLString)') format('\(fontFormat)');
      }

      """
  }

  private func readiumLineLengthValue(for pageMargins: Double) -> String {
    let normalizedMargins = max(0, pageMargins)
    let horizontalPadding = normalizedMargins * 20.0
    let totalInset = max(0, horizontalPadding * 2.0)
    return "calc(100% - \(String(format: "%.2f", totalInset))px)"
  }

  private func makeFontWeightCSS() -> String {
    """
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] {
      font-weight: var(--USER__fontWeight) !important;
    }
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] body,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] p,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] li,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] div,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] dt,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] dd,
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] i:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] i:not([xml\\:lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] em:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] em:not([xml\\:lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] cite:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] cite:not([xml\\:lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] b:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] b:not([xml\\:lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] strong:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] strong:not([xml\\:lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] span:not([lang]),
    :root[style*="readium-font-weight-on"][style*="--USER__fontWeight"] span:not([xml\\:lang]) {
      font-weight: var(--USER__fontWeight) !important;
    }

    """
  }

  private func makeDarkTextColorOverrideCSS(theme: ReaderTheme) -> String {
    guard theme.isDark else {
      return ""
    }

    return """
      :root[style*="--USER__textColor"] body {
        color: var(--USER__textColor) !important;
        -webkit-text-fill-color: var(--USER__textColor) !important;
      }

      :root[style*="--USER__textColor"] body *:not(a) {
        color: inherit !important;
        background-color: transparent !important;
        border-color: currentColor !important;
        -webkit-text-fill-color: currentColor !important;
      }

      :root[style*="--USER__textColor"] body svg text {
        fill: currentColor !important;
        stroke: none !important;
      }

      :root[style*="--USER__linkColor"] body a:link,
      :root[style*="--USER__linkColor"] body a:link * {
        color: var(--USER__linkColor) !important;
        -webkit-text-fill-color: var(--USER__linkColor) !important;
      }

      :root[style*="--USER__visitedColor"] body a:visited,
      :root[style*="--USER__visitedColor"] body a:visited * {
        color: var(--USER__visitedColor) !important;
        -webkit-text-fill-color: var(--USER__visitedColor) !important;
      }

      :root[style*="--USER__backgroundColor"] body,
      :root[style*="--USER__backgroundColor"] body * {
        background-color: transparent !important;
      }

      """
  }

  private var darkThemeLinkColors: (link: String, visited: String) {
    ("#63CAFF", "#0099E5")
  }

  private func makePaginationCompatibilityCSS() -> String {
    return """
      body {
        display: flow-root;
        height: auto !important;
        min-height: 100vh !important;
        max-height: none !important;
      }

      """
  }
  private func shouldUseLightImageBlend(for theme: ReaderTheme) -> Bool {
    switch theme {
    case .white, .lightQuiet, .lightSepia:
      return true
    default:
      return false
    }
  }

  private static func normalizedPageMargins(_ value: Double) -> Double {
    let normalized = value > 4.0 ? value / 20.0 : value
    return max(0, normalized)
  }

  private static func normalizedTapScrollPercentage(_ value: Double) -> Double {
    min(100.0, max(25.0, value))
  }
}

nonisolated enum ThemeChoice: String, CaseIterable, Identifiable {
  case system
  case quiet
  case sepia
  case green

  var id: String { rawValue }

  func resolvedTheme(for colorScheme: ColorScheme?) -> ReaderTheme {
    let isDark = colorScheme == .dark
    switch self {
    case .system: return isDark ? .black : .white
    case .quiet: return isDark ? .darkQuiet : .lightQuiet
    case .sepia: return isDark ? .darkSepia : .lightSepia
    case .green: return isDark ? .darkGreen : .lightGreen
    }
  }
}

nonisolated enum ReaderTheme: String, CaseIterable {
  case white
  case black
  case lightQuiet
  case darkQuiet
  case lightSepia
  case darkSepia
  case lightGreen
  case darkGreen

  var backgroundColorHex: String {
    switch self {
    case .white: return "#FFFFFF"
    case .black: return "#000000"
    case .lightQuiet: return "#FAFAFA"
    case .darkQuiet: return "#1E1E1E"
    case .lightSepia: return "#F4ECD8"
    case .darkSepia: return "#382E25"
    case .lightGreen: return "#C7EDCC"
    case .darkGreen: return "#1B261B"
    }
  }

  var textColorHex: String {
    switch self {
    case .white: return "#000000"
    case .black: return "#E0E0E0"
    case .lightQuiet: return "#111111"
    case .darkQuiet: return "#BDBDBD"
    case .lightSepia: return "#5C4A37"
    case .darkSepia: return "#E3D5C1"
    case .lightGreen: return "#1A3A1F"
    case .darkGreen: return "#D1E0D1"
    }
  }

  var isDark: Bool {
    switch self {
    case .black, .darkQuiet, .darkSepia, .darkGreen:
      return true
    default:
      return false
    }
  }

  var isSepia: Bool {
    switch self {
    case .lightSepia, .darkSepia, .lightGreen, .darkGreen:
      return true
    default:
      return false
    }
  }

  @MainActor
  var backgroundColor: Color {
    Color(hex: backgroundColorHex) ?? .black
  }

  @MainActor
  var textColor: Color {
    Color(hex: textColorHex) ?? .white
  }
}

nonisolated enum FontFamilyChoice: Hashable, Identifiable {
  case publisher
  case system(String)

  static let publisherStorageValue = "__kmreader_publisher_default__"
  static let publisherDisplayValue = String(localized: "Publisher Default")
  static let legacyPublisherValues: Set<String> = [
    "Publisher Default",
    "Verleger-Standard",
    "Par défaut de l'éditeur",
    "出版社デフォルト",
    "출판사 기본값",
    "出版商默认",
    "出版商預設",
    publisherDisplayValue,
  ]

  var id: String { rawValue }

  var rawValue: String {
    switch self {
    case .publisher: return FontFamilyChoice.publisherStorageValue
    case .system(let name): return name
    }
  }

  init(rawValue: String) {
    if rawValue == FontFamilyChoice.publisherStorageValue
      || FontFamilyChoice.legacyPublisherValues.contains(rawValue)
    {
      self = .publisher
    } else {
      self = .system(rawValue)
    }
  }

  var displayName: String {
    switch self {
    case .publisher: return FontFamilyChoice.publisherDisplayValue
    case .system(let name): return name
    }
  }

  var fontName: String? {
    switch self {
    case .publisher: return nil
    case .system(let name): return name
    }
  }
}
