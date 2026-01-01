//
//  HorizontalScrollButtons.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

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
    #if os(macOS)
      HStack {
        scrollButton(direction: .left)
        Spacer()
        scrollButton(direction: .right)
      }
      .opacity(isVisible ? 1 : 0)
      .animation(.easeInOut(duration: 0.2), value: isVisible)
      .allowsHitTesting(isVisible)
    #else
      EmptyView()
    #endif
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
        let step = 3  // scroll by 3 items at a time
        switch direction {
        case .left:
          currentIndex = max(0, currentIndex - step)
        case .right:
          currentIndex = min(itemIds.count - 1, currentIndex + step)
        }
        if let itemId = itemIds[safe: currentIndex] {
          scrollProxy.scrollTo(itemId, anchor: .leading)
        }
      }
    } label: {
      ZStack {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: 44, height: 44)
          .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

        Image(systemName: direction.systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
      }
      .padding(12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(canScroll ? 1 : 0.3)
    .disabled(!canScroll)
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
