//
//  Author.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct Author: Codable, Equatable, Hashable {
  let name: String
  let role: String
}

extension Author {
  var roleDisplayName: String {
    switch role.lowercased() {
    case "writer", "author":
      return "Writer"
    case "penciller", "artist", "illustrator":
      return "Artist"
    case "colorist":
      return "Colorist"
    case "letterer":
      return "Letterer"
    case "cover":
      return "Cover"
    case "editor":
      return "Editor"
    case "translator":
      return "Translator"
    case "inker":
      return "Inker"
    default:
      return role.capitalized
    }
  }

  var roleIcon: String {
    switch role.lowercased() {
    case "writer", "author":
      return "pencil"
    case "penciller", "artist", "illustrator":
      return "paintbrush"
    case "colorist":
      return "paintpalette.fill"
    case "letterer":
      return "textformat"
    case "cover":
      return "photo"
    case "editor":
      return "scissors"
    case "translator":
      return "globe"
    case "inker":
      return "pencil.tip"
    default:
      return "person"
    }
  }
}
