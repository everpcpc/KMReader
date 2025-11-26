//
//  EpubReaderPreferences.swift
//  KMReader
//
//  Created by Komga iOS Client
//

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

  init(
    fontFamily: FontFamilyChoice = .publisher,
    fontSize: Double = 1.0,
    pagination: PaginationMode = .paged,
    layout: LayoutChoice = .auto,
    theme: ThemeChoice = .system
  ) {
    self.fontFamily = fontFamily
    self.fontSize = fontSize
    self.pagination = pagination
    self.layout = layout
    self.theme = theme
  }

  init() {
    self.init(
      fontFamily: .publisher,
      fontSize: 1.0,
      pagination: .paged,
      layout: .auto,
      theme: .system
    )
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
    self.init(
      fontFamily: font, fontSize: fontSize, pagination: pagination, layout: layout, theme: theme)
  }

  var rawValue: String {
    let dict: [String: Any] = [
      "fontFamily": fontFamily.rawValue,
      "fontSize": fontSize,
      "pagination": pagination.rawValue,
      "layout": layout.rawValue,
      "theme": theme.rawValue,
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict),
      let json = String(data: data, encoding: .utf8)
    {
      return json
    }
    return "{}"
  }

  func toPreferences() -> EPUBPreferences {
    EPUBPreferences(
      fontFamily: fontFamily.fontFamily,
      fontSize: fontSize,
      scroll: pagination == .scroll,
      spread: layout.spread,
      theme: theme.theme,
    )
  }

  static func from(preferences: EPUBPreferences) -> EpubReaderPreferences {
    EpubReaderPreferences(
      fontFamily: FontFamilyChoice.from(preferences.fontFamily),
      fontSize: preferences.fontSize ?? 1.0,
      pagination: (preferences.scroll ?? false) ? .scroll : .paged,
      layout: LayoutChoice.from(preferences.spread),
      theme: ThemeChoice.from(preferences.theme)
    )
  }
}

enum PaginationMode: String, CaseIterable, Identifiable {
  case paged
  case scroll

  var id: String { rawValue }
  var title: String {
    switch self {
    case .paged: return "Paged"
    case .scroll: return "Continuous Scroll"
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
    case .auto: return "Auto"
    case .single: return "Single Page"
    case .dual: return "Dual Page"
    }
  }

  var icon: String {
    switch self {
    case .auto: return "sparkles"
    case .single: return "rectangle.portrait"
    case .dual: return "rectangle.split.2x1"
    }
  }

  var spread: Spread {
    switch self {
    case .auto: return .auto
    case .single: return .never
    case .dual: return .always
    }
  }

  static func from(_ spread: Spread?) -> LayoutChoice {
    switch spread {
    case .some(.never): return .single
    case .some(.always): return .dual
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
    case .system: return "System"
    case .light: return "Light"
    case .sepia: return "Sepia"
    case .dark: return "Dark"
    }
  }
  var theme: Theme? {
    switch self {
    case .system: return nil
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

  static let publisherValue = "Publisher Default"

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
