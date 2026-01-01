//
//  LayoutModePicker.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LayoutModePicker: View {
  @Binding var selection: BrowseLayoutMode

  private var animatedSelection: Binding<BrowseLayoutMode> {
    Binding(
      get: { selection },
      set: { newValue in
        withAnimation {
          selection = newValue
        }
      }
    )
  }

  var body: some View {
    Menu {
      Picker("Layout Mode", selection: animatedSelection) {
        ForEach(BrowseLayoutMode.allCases) { mode in
          Label(mode.displayName, systemImage: mode.iconName)
            .tag(mode)
        }
      }.pickerStyle(.inline)
    } label: {
      Image(systemName: selection.iconName)
    }
  }
}
