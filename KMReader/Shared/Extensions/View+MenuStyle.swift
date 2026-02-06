//
//  View+MenuStyle.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  func appMenuStyle() -> some View {
    menuStyle(.button)
      .menuIndicator(.hidden)
  }
}
