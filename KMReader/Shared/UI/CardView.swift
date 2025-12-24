//
//  CardView.swift
//  KMReader
//

import SwiftUI

/// A view that display as card
struct CardView<Content: View>: View {
  let padding: CGFloat
  let cornerRadius: CGFloat
  let background: Color?
  let shadow: Color?
  let content: () -> Content

  init(
    padding: CGFloat = 4,
    cornerRadius: CGFloat = 8,
    background: Color? = nil,
    shadow: Color? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.padding = padding
    self.cornerRadius = cornerRadius
    self.background = background
    self.shadow = shadow
    self.content = content
  }

  var body: some View {
    VStack {
      content().padding(padding)
    }
    .background {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(background ?? .cardBackground)
        .shadow(color: shadow ?? Color.black.opacity(0.2), radius: 2)
    }
  }
}

#Preview {
  VStack {
    Spacer()
    CardView {
      Text("Hello, World!")
    }
    Spacer()
  }.padding()
}
