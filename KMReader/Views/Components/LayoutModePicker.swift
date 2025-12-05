//
//  LayoutModePicker.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LayoutModePicker: View {
  @AppStorage("browseLayout") private var layoutMode: BrowseLayoutMode = .grid

  var body: some View {
    Menu {
      Picker("Layout", selection: $layoutMode) {
        ForEach(BrowseLayoutMode.allCases) { mode in
          Label(mode.displayName, systemImage: mode.iconName).tag(mode)
        }
      }
      .pickerStyle(.inline)
    } label: {
      Label(layoutMode.displayName, systemImage: layoutMode.iconName)
    }
  }
}
