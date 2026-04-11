//
// View+ButtonStyle.swift
//
//

import SwiftUI

enum AdaptiveButtonStyleType {
  case borderedProminent
  case bordered
  case borderless
  case plain
}

enum GlassEffectType {
  case clear
  case regular
}

private struct LegacyGlassSurfaceModifier<SurfaceShape: Shape>: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  let type: GlassEffectType
  let shape: SurfaceShape

  func body(content: Content) -> some View {
    content
      .background(backgroundStyle, in: shape)
      .overlay {
        shape
          .stroke(borderColor, lineWidth: reduceTransparency ? 1 : 0.8)
      }
      .shadow(
        color: reduceTransparency ? .clear : .black.opacity(type == .clear ? 0.08 : 0.14),
        radius: type == .clear ? 4 : 8,
        x: 0,
        y: 2
      )
  }

  private var backgroundStyle: AnyShapeStyle {
    if reduceTransparency {
      return AnyShapeStyle(reducedTransparencyColor)
    }

    switch type {
    case .clear:
      return AnyShapeStyle(.ultraThinMaterial)
    case .regular:
      return AnyShapeStyle(.regularMaterial)
    }
  }

  private var borderColor: Color {
    if reduceTransparency {
      return .primary.opacity(0.12)
    }

    switch type {
    case .clear:
      return .white.opacity(0.18)
    case .regular:
      return .white.opacity(0.24)
    }
  }

  private var reducedTransparencyColor: Color {
    #if os(iOS)
      return type == .clear ? Color(.secondarySystemBackground) : Color(.systemBackground)
    #elseif os(tvOS)
      return type == .clear ? Color.black.opacity(0.84) : Color.black.opacity(0.92)
    #elseif os(macOS)
      return type == .clear ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor)
    #else
      return .gray
    #endif
  }
}

extension View {
  @ViewBuilder
  func adaptiveButtonStyle(_ style: AdaptiveButtonStyleType) -> some View {
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
      switch style {
      case .borderedProminent:
        #if os(tvOS)
          self.buttonStyle(.glass)
        #else
          self.buttonStyle(.glassProminent)
        #endif
      case .bordered:
        self.buttonStyle(.glass)
      case .borderless:
        self.buttonStyle(.glass)
      case .plain:
        #if os(tvOS)
          self.buttonStyle(.card)
        #elseif os(iOS)
          self.buttonStyle(.squish).hoverEffect(.lift)
        #elseif os(macOS)
          self.buttonStyle(.squish).macHoverEffect()
        #else
          self.buttonStyle(.plain)
        #endif
      }
    } else {
      switch style {
      case .borderedProminent:
        self.buttonStyle(.borderedProminent)
      case .bordered:
        self
          .buttonStyle(.bordered)
          .legacyGlassSurface(.regular, in: ButtonBorderShape.buttonBorder)
      case .borderless:
        self
          .buttonStyle(.borderless)
          .legacyGlassSurface(.regular, in: ButtonBorderShape.buttonBorder)
      case .plain:
        #if os(tvOS)
          self.buttonStyle(.card)
        #elseif os(iOS)
          self.buttonStyle(.squish).hoverEffect(.lift)
        #elseif os(macOS)
          self.buttonStyle(.squish).macHoverEffect()
        #else
          self.buttonStyle(.plain)
        #endif
      }
    }
  }

  @ViewBuilder
  func glassEffectIfAvailable(_ type: GlassEffectType, enabled: Bool = true) -> some View {
    if enabled {
      if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
        switch type {
        case .clear: self.glassEffect(.clear)
        case .regular: self.glassEffect(.regular)
        }
      } else {
        self.legacyGlassSurface(type, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    } else {
      self
    }
  }

  @ViewBuilder
  func glassEffectIfAvailable<S: Shape>(_ type: GlassEffectType, enabled: Bool = true, in shape: S)
    -> some View
  {
    if enabled {
      if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
        switch type {
        case .clear: self.glassEffect(.clear, in: shape)
        case .regular: self.glassEffect(.regular, in: shape)
        }
      } else {
        self.legacyGlassSurface(type, in: shape)
      }
    } else {
      self
    }
  }

  private func legacyGlassSurface<S: Shape>(_ type: GlassEffectType, in shape: S) -> some View {
    modifier(LegacyGlassSurfaceModifier(type: type, shape: shape))
  }
}
