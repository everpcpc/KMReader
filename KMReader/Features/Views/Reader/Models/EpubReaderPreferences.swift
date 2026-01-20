//
//  EpubReaderPreferences.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)

  enum EpubConstants {
    static let defaultFontSize: Double = 16.0

    static let defaultLetterSpacing: Double = 0.0
    static let defaultWordSpacing: Double = 0.0

    static let defaultLineHeight: Double = 1.2

    static let defaultParagraphSpacing: Double = 0.5
    static let defaultParagraphIndent: Double = 2.0

    static let defaultPageMargins: Double = 1.0
    static let defaultFontWeight: Double = 1.0
  }

  import Foundation
  import SwiftUI

  struct EpubReaderPreferences: RawRepresentable, Equatable {
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
      theme.resolvedTheme(for: colorScheme) ?? .light
    }

    func makeCSS(theme: ReaderTheme) -> String {
      let fontSize = fontSize
      let fontWeightValue = 300 + Int(fontWeight * 160)
      let letterSpacingEm = letterSpacing
      let wordSpacingEm = wordSpacing
      let lineHeightValue = lineHeight
      let paragraphSpacingEm = paragraphSpacing
      let paragraphIndentEm = paragraphIndent

      // Only set font-family if user selected a specific font, otherwise use EPUB's default
      let fontFamilyCSS = fontFamily.fontName.map { "font-family: \($0);" } ?? ""

      // Internal CSS padding controlled by user's pageMargins setting
      let basePadding = 10.0
      let internalPadding = Int(basePadding * pageMargins)

      return """
          body {
            margin: 0;
            padding: \(internalPadding)px;
            background-color: \(theme.backgroundColor);
            color: \(theme.textColor);
            \(fontFamilyCSS)
            font-size: \(fontSize)px;
            font-weight: \(fontWeightValue);
            letter-spacing: \(letterSpacingEm)em;
            word-spacing: \(wordSpacingEm)em;
            line-height: \(lineHeightValue);
          }
          p {
            margin: 0 !important;
            margin-bottom: \(max(0, paragraphSpacingEm))em !important;
            text-indent: \(max(0, paragraphIndentEm))em !important;
          }
        """
    }
  }

  enum ThemeChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case sepia
    case dark

    var id: String { rawValue }
    var title: String {
      switch self {
      case .system: return String(localized: "System")
      case .light: return String(localized: "Light")
      case .sepia: return String(localized: "Sepia")
      case .dark: return String(localized: "Dark")
      }
    }
    func resolvedTheme(for colorScheme: ColorScheme?) -> ReaderTheme? {
      switch self {
      case .system:
        guard let colorScheme else { return nil }
        return colorScheme == .dark ? .dark : .light
      case .light: return .light
      case .sepia: return .sepia
      case .dark: return .dark
      }
    }
  }

  enum ReaderTheme: String, CaseIterable {
    case light
    case sepia
    case dark

    var backgroundColor: String {
      switch self {
      case .light: return "#FFFFFF"
      case .sepia: return "#F4ECD8"
      case .dark: return "#1E1E1E"
      }
    }

    var textColor: String {
      switch self {
      case .light: return "#000000"
      case .sepia: return "#5C4A37"
      case .dark: return "#E0E0E0"
      }
    }
  }

  enum FontFamilyChoice: Hashable, Identifiable {
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
#endif
