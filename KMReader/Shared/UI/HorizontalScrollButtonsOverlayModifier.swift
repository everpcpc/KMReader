//
// HorizontalScrollButtonsOverlayModifier.swift
//
//

import SwiftUI

#if os(macOS)
  private struct HorizontalScrollButtonsOverlayModifier<ID: Hashable>: ViewModifier {
    let scrollProxy: ScrollViewProxy
    let itemIds: [ID]

    @State private var areButtonsVisible = false

    func body(content: Content) -> some View {
      content
        .overlay {
          HorizontalScrollButtons(
            scrollProxy: scrollProxy,
            itemIds: itemIds,
            isVisible: areButtonsVisible
          )
          .animation(.easeOut(duration: 0.15), value: areButtonsVisible)
        }
        .onHover { hovering in
          guard areButtonsVisible != hovering else { return }
          areButtonsVisible = hovering
        }
    }
  }

  extension View {
    func macHorizontalScrollButtons<ID: Hashable>(
      scrollProxy: ScrollViewProxy,
      itemIds: [ID]
    ) -> some View {
      modifier(
        HorizontalScrollButtonsOverlayModifier(
          scrollProxy: scrollProxy,
          itemIds: itemIds
        )
      )
    }
  }
#endif
