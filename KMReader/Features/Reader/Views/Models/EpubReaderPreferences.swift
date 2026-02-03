//
//  EpubReaderPreferences.swift
//  KMReader
//
//  Created by Komga iOS Client
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
}

nonisolated struct EpubReaderPreferences: RawRepresentable, Equatable {
  typealias RawValue = String

  // Keep this list in sync with makeReadiumPayload.
  static let readiumPropertyKeys: [String] = [
    "--RS__textColor",
    "--RS__backgroundColor",
    "--USER__fontOverride",
    "--USER__fontFamily",
    "--USER__fontWeightOverride",
    "--USER__fontWeight",
    "--USER__colCount",
    "--USER__pageMargins",
    "--USER__appearance",
    "--USER__advancedSettings",
    "--USER__fontSize",
    "--USER__lineHeight",
    "--USER__paraSpacing",
    "--USER__paraIndent",
    "--USER__wordSpacing",
    "--USER__letterSpacing",
  ]

  var theme: ThemeChoice
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

  init(
    theme: ThemeChoice = .system,
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
  ) {
    self.theme = theme
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

    self.init(
      theme: theme,
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
    )
  }

  var rawValue: String {
    var dict: [String: Any] = [
      "theme": theme.rawValue,
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
    rootURL: URL? = nil
  ) -> (css: String, properties: [String: String?]) {
    let fontName = fontFamily.fontName

    var properties: [String: String?] = [
      "--RS__textColor": theme.textColorHex,
      "--RS__backgroundColor": theme.backgroundColorHex,
    ]
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
    properties["--USER__colCount"] = columnCount.readiumValue
    properties["--USER__pageMargins"] = String(format: "%.2f", max(0, pageMargins))

    if theme.isDark {
      properties["--USER__appearance"] = "readium-night-on"
    } else {
      properties["--USER__appearance"] = nil
    }

    if advancedLayout {
      let fontSizePercent = fontSize * 100
      let letterSpacingRem = max(0, letterSpacing)
      let wordSpacingRem = max(0, wordSpacing)
      let paragraphSpacingRem = max(0, paragraphSpacing)
      let paragraphIndentRem = max(0, paragraphIndent)

      properties["--USER__advancedSettings"] = "readium-advanced-on"
      properties["--USER__fontSize"] = String(format: "%.2f%%", fontSizePercent)
      properties["--USER__lineHeight"] = String(format: "%.2f", lineHeight)
      properties["--USER__paraSpacing"] = String(format: "%.2frem", paragraphSpacingRem)
      properties["--USER__paraIndent"] = String(format: "%.2frem", paragraphIndentRem)
      properties["--USER__wordSpacing"] = String(format: "%.2frem", wordSpacingRem)
      properties["--USER__letterSpacing"] = String(format: "%.2frem", letterSpacingRem)
    } else {
      properties["--USER__advancedSettings"] = nil
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

    var imageBlendCSS = ""
    if shouldUseLightImageBlend(for: theme) {
      imageBlendCSS = """
        :root[data-kmreader-theme="light"] img,
        :root[data-kmreader-theme="light"] svg {
          mix-blend-mode: multiply;
        }

        """
    }

    let backgroundFillCSS = """
      body {
        min-height: 100vh;
        display: flow-root;
      }

      """

    let fontWeightCSS = makeFontWeightCSS()
    return (
      css: fontFaceCSS + fontWeightCSS + imageBlendCSS + backgroundFillCSS,
      properties: properties
    )
  }

  func makeCSS(theme: ReaderTheme, fontPath: String? = nil, rootURL: URL? = nil) -> String {
    makeReadiumPayload(theme: theme, fontPath: fontPath, rootURL: rootURL).css
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

  static let publisherValue = String(localized: "Publisher Default")

  var id: String { rawValue }

  var rawValue: String {
    switch self {
    case .publisher: return FontFamilyChoice.publisherValue
    case .system(let name): return name
    }
  }

  init(rawValue: String) {
    if rawValue == FontFamilyChoice.publisherValue {
      self = .publisher
    } else {
      self = .system(rawValue)
    }
  }

  var fontName: String? {
    switch self {
    case .publisher: return nil
    case .system(let name): return name
    }
  }
}
