//
//  HorizontalScrollButtons.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(macOS)
  /// Overlay buttons for horizontal ScrollView navigation (left/right arrows)
  /// Only visible on macOS, visibility controlled by parent via isVisible
  struct HorizontalScrollButtons<ID: Hashable>: View {
    let scrollProxy: ScrollViewProxy
    let itemIds: [ID]
    let isVisible: Bool

    @State private var currentIndex: Int = 0

    private var canScrollLeft: Bool {
      currentIndex > 0
    }

    private var canScrollRight: Bool {
      currentIndex < itemIds.count - 1
    }

    var body: some View {
      ZStack {
        scrollButton(direction: .left)
          .frame(maxWidth: .infinity, alignment: .leading)

        scrollButton(direction: .right)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .opacity(isVisible ? 1 : 0)
      .allowsHitTesting(isVisible)
    }

    private enum ScrollDirection {
      case left
      case right

      var systemImage: String {
        switch self {
        case .left: "chevron.left"
        case .right: "chevron.right"
        }
      }
    }

    @ViewBuilder
    private func scrollButton(direction: ScrollDirection) -> some View {
      let canScroll = direction == .left ? canScrollLeft : canScrollRight

      Button {
        withAnimation(.easeInOut(duration: 0.3)) {
          let step = 5  // scroll by 5 items at a time
          switch direction {
          case .left:
            currentIndex = max(0, currentIndex - step)
          case .right:
            currentIndex = min(itemIds.count - 1, currentIndex + step)
          }
          if let itemId = itemIds[safe: currentIndex] {
            scrollProxy.scrollTo(itemId, anchor: .center)
          }
        }
      } label: {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.thinMaterial)
            .frame(width: 24, height: 60)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)

          Image(systemName: direction.systemImage)
            .foregroundStyle(canScroll ? .primary : .secondary)
            .bold()
            .scaleEffect(x: 1.0, y: 2.5)
        }
        .padding(8)
        .contentShape(Rectangle())
      }
      .adaptiveButtonStyle(.plain)
      .opacity(canScroll ? 1 : 0.6)
      .disabled(!canScroll)
    }
  }

  extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
      indices.contains(index) ? self[index] : nil
    }
  }
#endif
