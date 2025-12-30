//
//  EpubReaderPreferences.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import Foundation
  import ReadiumNavigator
  import SwiftUI

  struct EpubReaderPreferences: RawRepresentable, Equatable {
    typealias RawValue = String

    var fontFamily: FontFamilyChoice
    var fontSize: Double
    var pagination: PaginationMode
    var layout: LayoutChoice
    var theme: ThemeChoice
    var wordSpacing: Double
    var paragraphSpacing: Double
    var paragraphIndent: Double
    var pageMargins: Double
    var letterSpacing: Double
    var lineHeight: Double
    var fontWeight: Double

    init(
      fontFamily: FontFamilyChoice = .publisher,
      fontSize: Double = 1.0,
      pagination: PaginationMode = .paged,
      layout: LayoutChoice = .auto,
      theme: ThemeChoice = .system,
      wordSpacing: Double = 1.0,
      paragraphSpacing: Double = 1.0,
      paragraphIndent: Double = 1.0,
      pageMargins: Double = 1.0,
      letterSpacing: Double = 1.0,
      lineHeight: Double = 1.0,
      fontWeight: Double = 1.0
    ) {
      self.fontFamily = fontFamily
      self.fontSize = fontSize
      self.pagination = pagination
      self.layout = layout
      self.theme = theme
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

      let fontString = dict["fontFamily"] as? String ?? FontFamilyChoice.publisher.rawValue
      let font = FontFamilyChoice(rawValue: fontString)
      let fontSize = dict["fontSize"] as? Double ?? 1.0
      let pagination = (dict["pagination"] as? String).flatMap(PaginationMode.init) ?? .paged
      let layout = (dict["layout"] as? String).flatMap(LayoutChoice.init) ?? .auto
      let theme = (dict["theme"] as? String).flatMap(ThemeChoice.init) ?? .system
      let wordSpacing = dict["wordSpacing"] as? Double ?? 1.0
      let paragraphSpacing = dict["paragraphSpacing"] as? Double ?? 1.0
      let paragraphIndent = dict["paragraphIndent"] as? Double ?? 1.0
      let pageMargins = dict["pageMargins"] as? Double ?? 1.0
      let letterSpacing = dict["letterSpacing"] as? Double ?? 1.0
      let lineHeight = dict["lineHeight"] as? Double ?? 1.0
      let fontWeight = dict["fontWeight"] as? Double ?? 1.0
      self.init(
        fontFamily: font,
        fontSize: fontSize,
        pagination: pagination,
        layout: layout,
        theme: theme,
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
        "fontFamily": fontFamily.rawValue,
        "fontSize": fontSize,
        "pagination": pagination.rawValue,
        "layout": layout.rawValue,
        "theme": theme.rawValue,
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

    func toPreferences(colorScheme: ColorScheme? = nil) -> EPUBPreferences {
      EPUBPreferences(
        columnCount: layout.columnCount,
        fontFamily: fontFamily.fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        lineHeight: lineHeight,
        pageMargins: pageMargins,
        paragraphIndent: paragraphIndent,
        paragraphSpacing: paragraphSpacing,
        scroll: pagination == .scroll,
        spread: .auto,
        theme: theme.resolvedTheme(for: colorScheme),
        wordSpacing: wordSpacing
      )
    }
  }

  enum PaginationMode: String, CaseIterable, Identifiable {
    case paged
    case scroll

    var id: String { rawValue }
    var title: String {
      switch self {
      case .paged: return String(localized: "Paged")
      case .scroll: return String(localized: "Continuous Scroll")
      }
    }
    var icon: String {
      switch self {
      case .paged: return "square.on.square"
      case .scroll: return "text.justify"
      }
    }
  }

  enum LayoutChoice: String, CaseIterable, Identifiable {
    case auto
    case single
    case dual

    var id: String { rawValue }

    var title: String {
      switch self {
      case .auto: return String(localized: "Auto")
      case .single: return String(localized: "Single Page")
      case .dual: return String(localized: "Dual Page")
      }
    }

    var icon: String {
      switch self {
      case .auto: return "sparkles"
      case .single: return "rectangle.portrait"
      case .dual: return "rectangle.split.2x1"
      }
    }

    var columnCount: ColumnCount? {
      switch self {
      case .auto: return nil
      case .single: return .one
      case .dual: return .two
      }
    }

    static func from(_ columnCount: ColumnCount?) -> LayoutChoice {
      switch columnCount {
      case .some(.one): return .single
      case .some(.two): return .dual
      default: return .auto
      }
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
    func resolvedTheme(for colorScheme: ColorScheme?) -> Theme? {
      switch self {
      case .system:
        guard let colorScheme else { return nil }
        return colorScheme == .dark ? .dark : .light
      case .light: return .light
      case .sepia: return .sepia
      case .dark: return .dark
      }
    }

    static func from(_ theme: Theme?) -> ThemeChoice {
      switch theme {
      case .some(.light): return .light
      case .some(.sepia): return .sepia
      case .some(.dark): return .dark
      default: return .system
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

    var fontFamily: FontFamily? {
      switch self {
      case .publisher: return nil
      case .system(let name): return FontFamily(rawValue: name)
      }
    }

    static func from(_ fontFamily: FontFamily?) -> FontFamilyChoice {
      guard let name = fontFamily?.rawValue else {
        return .publisher
      }
      return .system(name)
    }
  }
#endif
