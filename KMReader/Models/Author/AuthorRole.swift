//
//  AuthorRole.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum AuthorRole: Equatable, Hashable, Sendable {
  case writer
  case penciller
  case inker
  case colorist
  case letterer
  case cover
  case editor
  case translator
  case custom(String)

  // Predefined cases for picker
  static let predefinedCases: [AuthorRole] = [
    .writer,
    .penciller,
    .inker,
    .colorist,
    .letterer,
    .cover,
    .editor,
    .translator,
  ]

  // Raw value for API communication
  var rawValue: String {
    switch self {
    case .writer: return "writer"
    case .penciller: return "penciller"
    case .inker: return "inker"
    case .colorist: return "colorist"
    case .letterer: return "letterer"
    case .cover: return "cover"
    case .editor: return "editor"
    case .translator: return "translator"
    case .custom(let value): return value
    }
  }

  // Localized display name
  var displayName: String {
    switch self {
    case .writer: return String(localized: "author_role.writer")
    case .penciller: return String(localized: "author_role.penciller")
    case .inker: return String(localized: "author_role.inker")
    case .colorist: return String(localized: "author_role.colorist")
    case .letterer: return String(localized: "author_role.letterer")
    case .cover: return String(localized: "author_role.cover")
    case .editor: return String(localized: "author_role.editor")
    case .translator: return String(localized: "author_role.translator")
    case .custom(let value): return value.capitalized
    }
  }

  // Icon for the role
  var icon: String {
    switch self {
    case .writer: return "pencil"
    case .penciller: return "paintbrush"
    case .inker: return "pencil.tip"
    case .colorist: return "paintpalette.fill"
    case .letterer: return "textformat"
    case .cover: return "photo"
    case .editor: return "scissors"
    case .translator: return "globe"
    case .custom: return "person"
    }
  }

  // Sort order for displaying authors
  // Priority: Writers, Pencilers, Inkers, Colorists, Letterers, Cover, Editors, Translators, and custom roles
  var sortOrder: Int {
    switch self {
    case .writer: return 0
    case .penciller: return 1
    case .inker: return 2
    case .colorist: return 3
    case .letterer: return 4
    case .cover: return 5
    case .editor: return 6
    case .translator: return 7
    case .custom: return 8
    }
  }

  // Initialize from string (for API responses)
  init(from string: String) {
    switch string.lowercased() {
    case "writer", "author":
      self = .writer
    case "penciller", "artist", "illustrator":
      self = .penciller
    case "inker":
      self = .inker
    case "colorist":
      self = .colorist
    case "letterer":
      self = .letterer
    case "cover":
      self = .cover
    case "editor":
      self = .editor
    case "translator":
      self = .translator
    default:
      self = .custom(string)
    }
  }
}
