//
//  EpubReaderPreferences.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

nonisolated enum EpubConstants {
  static let defaultFontSize: Double = 16.0

  static let defaultLetterSpacing: Double = 0.0
  static let defaultWordSpacing: Double = 0.0

  static let defaultLineHeight: Double = 1.2

  static let defaultParagraphSpacing: Double = 0.5
  static let defaultParagraphIndent: Double = 2.0

  static let defaultPageMargins: Double = 16.0
  static let defaultFontWeight: Double = 1.0
}

nonisolated struct EpubReaderPreferences: RawRepresentable, Equatable {
  typealias RawValue = String

  var theme: ThemeChoice
  var fontFamily: FontFamilyChoice
  var fontSize: Double
  var wordSpacing: Double
  var paragraphSpacing: Double
  var paragraphIndent: Double
  var pageMargins: Double
  var letterSpacing: Double
  var lineHeight: Double
  var fontWeight: Double

  init(
    theme: ThemeChoice = .system,
    fontFamily: FontFamilyChoice = .publisher,
    fontSize: Double = EpubConstants.defaultFontSize,
    wordSpacing: Double = EpubConstants.defaultWordSpacing,
    paragraphSpacing: Double = EpubConstants.defaultParagraphSpacing,
    paragraphIndent: Double = EpubConstants.defaultParagraphIndent,
    pageMargins: Double = EpubConstants.defaultPageMargins,
    letterSpacing: Double = EpubConstants.defaultLetterSpacing,
    lineHeight: Double = EpubConstants.defaultLineHeight,
    fontWeight: Double = EpubConstants.defaultFontWeight
  ) {
    self.theme = theme
    self.fontFamily = fontFamily
    self.fontSize = fontSize
    self.wordSpacing = wordSpacing
    self.paragraphSpacing = paragraphSpacing
    self.paragraphIndent = paragraphIndent
    self.pageMargins = pageMargins
    self.letterSpacing = letterSpacing
    self.lineHeight = lineHeight
    self.fontWeight = fontWeight
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
    let fontSize = dict["fontSize"] as? Double ?? EpubConstants.defaultFontSize
    let wordSpacing = dict["wordSpacing"] as? Double ?? EpubConstants.defaultWordSpacing
    let paragraphSpacing = dict["paragraphSpacing"] as? Double ?? EpubConstants.defaultParagraphSpacing
    let paragraphIndent = dict["paragraphIndent"] as? Double ?? EpubConstants.defaultParagraphIndent
    let pageMargins = dict["pageMargins"] as? Double ?? EpubConstants.defaultPageMargins
    let letterSpacing = dict["letterSpacing"] as? Double ?? EpubConstants.defaultLetterSpacing
    let lineHeight = dict["lineHeight"] as? Double ?? EpubConstants.defaultLineHeight
    let fontWeight = dict["fontWeight"] as? Double ?? EpubConstants.defaultFontWeight
    self.init(
      theme: theme,
      fontFamily: font,
      fontSize: fontSize,
      wordSpacing: wordSpacing,
      paragraphSpacing: paragraphSpacing,
      paragraphIndent: paragraphIndent,
      pageMargins: pageMargins,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      fontWeight: fontWeight
    )
  }

  var rawValue: String {
    let dict: [String: Any] = [
      "theme": theme.rawValue,
      "fontFamily": fontFamily.rawValue,
      "fontSize": fontSize,
      "wordSpacing": wordSpacing,
      "paragraphSpacing": paragraphSpacing,
      "paragraphIndent": paragraphIndent,
      "pageMargins": pageMargins,
      "letterSpacing": letterSpacing,
      "lineHeight": lineHeight,
      "fontWeight": fontWeight,
    ]
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

  func makeCSS(theme: ReaderTheme, fontPath: String? = nil, rootURL: URL? = nil) -> String {
    let fontSize = fontSize
    let fontWeightValue = 240 + Int(fontWeight * 160)
    let letterSpacingEm = letterSpacing
    let wordSpacingEm = wordSpacing
    let lineHeightValue = lineHeight
    let paragraphSpacingEm = paragraphSpacing
    let paragraphIndentEm = paragraphIndent

    // Only set font-family if user selected a specific font, otherwise use EPUB's default
    let fontFamilyCSS = fontFamily.fontName.map { "font-family: '\($0)' !important;" } ?? ""

    // Internal CSS padding controlled by user's pageMargins setting (in pixels)
    let internalPadding = Int(pageMargins)

    // Generate @font-face rule for imported fonts
    var fontFaceCSS = ""
    if let fontName = fontFamily.fontName, let path = fontPath, let rootURL = rootURL {
      // Font files are copied to {rootURL}/.fonts/ directory
      // Use absolute file:// URL since fonts are within the allowingReadAccessTo scope
      let fileName = URL(fileURLWithPath: path).lastPathComponent
      let fontURL = rootURL.appendingPathComponent(".fonts").appendingPathComponent(fileName)
      let fileURLString = fontURL.absoluteString

      // Determine font format from file extension
      let fontFormat = path.hasSuffix(".otf") ? "opentype" : "truetype"
      fontFaceCSS = """
        @font-face {
          font-family: '\(fontName)';
          src: url('\(fileURLString)') format('\(fontFormat)');
        }

        """
    }

    return """
        \(fontFaceCSS)body {
          margin: 0;
          padding: \(internalPadding)px;
          background-color: \(theme.backgroundColorHex);
          color: \(theme.textColorHex);
          \(fontFamilyCSS)
          font-size: \(fontSize)px !important;
          font-weight: \(fontWeightValue);
          letter-spacing: \(letterSpacingEm)em;
          word-spacing: \(wordSpacingEm)em;
          line-height: \(lineHeightValue);
        }
        p, div, span, li {
          \(fontFamilyCSS.isEmpty ? "" : "font-family: inherit !important;")
          font-size: inherit !important;
        }
        p {
          margin: 0 !important;
          margin-bottom: \(max(0, paragraphSpacingEm))em !important;
          text-indent: \(max(0, paragraphIndentEm))em !important;
        }
      """
  }
}

nonisolated enum ThemeChoice: String, CaseIterable, Identifiable {
  case system
  case quiet
  case sepia
  case green

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return String(localized: "System")
    case .quiet: return String(localized: "Quiet")
    case .sepia: return String(localized: "Sepia")
    case .green: return String(localized: "Green")
    }
  }

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
