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
  var typeScale: Double
  var pagination: PaginationMode
  var layout: LayoutChoice
  var theme: ThemeChoice

  init(
    fontFamily: FontFamilyChoice = .publisher,
    typeScale: Double = 1.0,
    pagination: PaginationMode = .paged,
    layout: LayoutChoice = .auto,
    theme: ThemeChoice = .system
  ) {
    self.fontFamily = fontFamily
    self.typeScale = typeScale
    self.pagination = pagination
    self.layout = layout
    self.theme = theme
  }

  init() {
    self.init(
      fontFamily: .publisher,
      typeScale: 1.0,
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

    var values: [String: String] = [:]
    rawValue
      .split(separator: ";")
      .forEach { component in
        let pair = component.split(separator: "=", maxSplits: 1).map(String.init)
        guard pair.count == 2 else { return }
        values[pair[0]] = Self.decode(pair[1])
      }

    self.init(
      fontFamily: FontFamilyChoice(rawValue: values["fontFamily"] ?? "") ?? .publisher,
      typeScale: values["typeScale"].flatMap(Double.init) ?? 1.0,
      pagination: PaginationMode(rawValue: values["pagination"] ?? "") ?? .paged,
      layout: LayoutChoice(rawValue: values["layout"] ?? "") ?? .auto,
      theme: ThemeChoice(rawValue: values["theme"] ?? "") ?? .system
    )
  }

  var rawValue: String {
    [
      "fontFamily=\(Self.encode(fontFamily.rawValue))",
      "typeScale=\(typeScale)",
      "pagination=\(pagination.rawValue)",
      "layout=\(layout.rawValue)",
      "theme=\(theme.rawValue)",
    ].joined(separator: ";")
  }

  func toPreferences() -> EPUBPreferences {
    EPUBPreferences(
      fontFamily: fontFamily.fontFamily,
      scroll: pagination == .scroll,
      spread: layout.spread,
      theme: theme.theme,
      typeScale: typeScale
    )
  }

  static func from(preferences: EPUBPreferences) -> EpubReaderPreferences {
    EpubReaderPreferences(
      fontFamily: FontFamilyChoice.from(preferences.fontFamily),
      typeScale: preferences.typeScale ?? 1.0,
      pagination: (preferences.scroll ?? false) ? .scroll : .paged,
      layout: LayoutChoice.from(preferences.spread),
      theme: ThemeChoice.from(preferences.theme)
    )
  }

  private static func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }

  private static func decode(_ value: String) -> String {
    value.removingPercentEncoding ?? value
  }
}

enum FontFamilyChoice: String, CaseIterable, Identifiable {
  case publisher
  case serif
  case sans
  case dyslexic
  case duo
  case georgia
  case helvetica

  var id: String { rawValue }

  var title: String {
    switch self {
    case .publisher: return "Publisher Default"
    case .serif: return "Serif"
    case .sans: return "Sans Serif"
    case .dyslexic: return "Open Dyslexic"
    case .duo: return "IA Writer Duospace"
    case .georgia: return "Georgia"
    case .helvetica: return "Helvetica Neue"
    }
  }

  var fontFamily: FontFamily? {
    switch self {
    case .publisher: return nil
    case .serif: return .serif
    case .sans: return .sansSerif
    case .dyslexic: return .openDyslexic
    case .duo: return .iaWriterDuospace
    case .georgia: return .georgia
    case .helvetica: return .helveticaNeue
    }
  }

  static func from(_ fontFamily: FontFamily?) -> FontFamilyChoice {
    switch fontFamily {
    case .some(.serif): return .serif
    case .some(.sansSerif): return .sans
    case .some(.openDyslexic): return .dyslexic
    case .some(.iaWriterDuospace): return .duo
    case .some(.georgia): return .georgia
    case .some(.helveticaNeue): return .helvetica
    default: return .publisher
    }
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
