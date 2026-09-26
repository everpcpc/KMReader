//
// ShadowPathView.swift
//
//

import SwiftUI

struct ShadowPathView: View {
  let color: Color
  let radius: CGFloat
  let x: CGFloat
  let y: CGFloat
  let cornerRadius: CGFloat

  var body: some View {
    ShadowPathRepresentable(
      color: color,
      radius: radius,
      x: x,
      y: y,
      cornerRadius: cornerRadius
    )
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

#if os(iOS) || os(tvOS)
  private struct ShadowPathRepresentable: UIViewRepresentable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> ShadowPathUIView {
      let view = ShadowPathUIView()
      updateUIView(view, context: context)
      return view
    }

    func updateUIView(_ uiView: ShadowPathUIView, context: Context) {
      uiView.apply(
        color: UIColor(color),
        radius: radius,
        offset: CGSize(width: x, height: y),
        cornerRadius: cornerRadius
      )
    }
  }

  private final class ShadowPathUIView: UIView {
    private var shadowColor: UIColor = .clear
    private var shadowRadius: CGFloat = 0
    private var shadowOffset: CGSize = .zero
    private var shadowCornerRadius: CGFloat = 0

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      backgroundColor = .clear
      layer.masksToBounds = false
      // SwiftUI skips representable updates on appearance changes when nothing
      // in the view tree reads colorScheme, so the layer must re-resolve its
      // frozen CGColor itself.
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
        (view: ShadowPathUIView, _) in
        view.updateShadowPath()
      }
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
      isUserInteractionEnabled = false
      backgroundColor = .clear
      layer.masksToBounds = false
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      updateShadowPath()
    }

    func apply(color: UIColor, radius: CGFloat, offset: CGSize, cornerRadius: CGFloat) {
      shadowColor = color
      shadowRadius = radius
      shadowOffset = offset
      shadowCornerRadius = cornerRadius
      updateShadowPath()
    }

    private func updateShadowPath() {
      layer.shadowColor = shadowColor.resolvedColor(with: traitCollection).cgColor
      layer.shadowOpacity = 1
      layer.shadowRadius = shadowRadius
      layer.shadowOffset = shadowOffset
      let path = UIBezierPath(
        roundedRect: bounds,
        cornerRadius: shadowCornerRadius
      )
      layer.shadowPath = path.cgPath
    }
  }
#elseif os(macOS)
  private struct ShadowPathRepresentable: NSViewRepresentable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> ShadowPathNSView {
      let view = ShadowPathNSView()
      updateNSView(view, context: context)
      return view
    }

    func updateNSView(_ nsView: ShadowPathNSView, context: Context) {
      nsView.apply(
        color: NSColor(color),
        radius: radius,
        offset: CGSize(width: x, height: -y),
        cornerRadius: cornerRadius
      )
    }
  }

  private final class ShadowPathNSView: NSView {
    private var shadowColor: NSColor = .clear
    private var shadowRadius: CGFloat = 0
    private var shadowOffset: CGSize = .zero
    private var shadowCornerRadius: CGFloat = 0

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
      layer?.masksToBounds = false
      layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
      wantsLayer = true
      layer?.masksToBounds = false
      layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func layout() {
      super.layout()
      updateShadowPath()
    }

    // See ShadowPathUIView's trait-change registration.
    override func viewDidChangeEffectiveAppearance() {
      super.viewDidChangeEffectiveAppearance()
      updateShadowPath()
    }

    func apply(color: NSColor, radius: CGFloat, offset: CGSize, cornerRadius: CGFloat) {
      shadowColor = color
      shadowRadius = radius
      shadowOffset = offset
      shadowCornerRadius = cornerRadius
      updateShadowPath()
    }

    private func updateShadowPath() {
      guard let layer = layer else { return }
      var resolvedColor = shadowColor.cgColor
      effectiveAppearance.performAsCurrentDrawingAppearance {
        resolvedColor = shadowColor.cgColor
      }
      layer.shadowColor = resolvedColor
      layer.shadowOpacity = 1
      layer.shadowRadius = shadowRadius
      layer.shadowOffset = shadowOffset
      let path = CGPath(
        roundedRect: bounds,
        cornerWidth: shadowCornerRadius,
        cornerHeight: shadowCornerRadius,
        transform: nil
      )
      layer.shadowPath = path
    }
  }
#endif
