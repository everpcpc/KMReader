//
// CircularProgressView.swift
//
//

#if os(iOS) || os(tvOS)
  import UIKit

  /// Apple Books-style download progress: a thin track ring with a solid pie
  /// sector growing clockwise from the top.
  final class CircularProgressView: UIView {
    var progress: Double = 0 {
      didSet { updatePie() }
    }

    var color: UIColor = .label {
      didSet { updateColors() }
    }

    private let trackLayer = CAShapeLayer()
    private let pieLayer = CAShapeLayer()

    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      trackLayer.fillColor = nil
      pieLayer.strokeColor = nil
      layer.addSublayer(trackLayer)
      layer.addSublayer(pieLayer)
      updateColors()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard bounds.width > 0, bounds.height > 0 else { return }
      let side = min(bounds.width, bounds.height)
      let lineWidth: CGFloat = 1.5
      let ringRect = CGRect(
        x: (bounds.width - side) / 2,
        y: (bounds.height - side) / 2,
        width: side,
        height: side
      ).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
      trackLayer.frame = bounds
      trackLayer.path = UIBezierPath(ovalIn: ringRect).cgPath
      trackLayer.lineWidth = lineWidth
      pieLayer.frame = bounds
      updatePie()
    }

    private func updatePie() {
      let clamped = min(max(progress, 0), 1)
      guard clamped > 0, bounds.width > 0 else {
        pieLayer.path = nil
        return
      }
      let center = CGPoint(x: bounds.midX, y: bounds.midY)
      let radius = (min(bounds.width, bounds.height) - 3) / 2
      let path = UIBezierPath()
      path.move(to: center)
      path.addArc(
        withCenter: center,
        radius: radius,
        startAngle: -.pi / 2,
        endAngle: -.pi / 2 + 2 * .pi * clamped,
        clockwise: true
      )
      path.close()
      pieLayer.path = path.cgPath
    }

    private func updateColors() {
      trackLayer.strokeColor = color.withAlphaComponent(0.3).cgColor
      pieLayer.fillColor = color.cgColor
    }
  }
#elseif os(macOS)
  import AppKit

  /// Apple Books-style download progress: a thin track ring with a solid pie
  /// sector growing clockwise from the top.
  final class CircularProgressView: NSView {
    var progress: Double = 0 {
      didSet { updatePie() }
    }

    var color: NSColor = .labelColor {
      didSet { updateColors() }
    }

    private let trackLayer = CAShapeLayer()
    private let pieLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
      trackLayer.fillColor = nil
      pieLayer.strokeColor = nil
      layer?.addSublayer(trackLayer)
      layer?.addSublayer(pieLayer)
      updateColors()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    // Match UIKit's y-down coordinates so both platforms share the same arc math.
    override var isFlipped: Bool {
      true
    }

    override func layout() {
      super.layout()
      guard bounds.width > 0, bounds.height > 0 else { return }
      let side = min(bounds.width, bounds.height)
      let lineWidth: CGFloat = 1.5
      let ringRect = CGRect(
        x: (bounds.width - side) / 2,
        y: (bounds.height - side) / 2,
        width: side,
        height: side
      ).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
      trackLayer.frame = bounds
      trackLayer.path = CGPath(ellipseIn: ringRect, transform: nil)
      trackLayer.lineWidth = lineWidth
      pieLayer.frame = bounds
      updatePie()
    }

    private func updatePie() {
      let clamped = min(max(progress, 0), 1)
      guard clamped > 0, bounds.width > 0 else {
        pieLayer.path = nil
        return
      }
      let center = CGPoint(x: bounds.midX, y: bounds.midY)
      let radius = (min(bounds.width, bounds.height) - 3) / 2
      let path = CGMutablePath()
      path.move(to: center)
      path.addArc(
        center: center,
        radius: radius,
        startAngle: -.pi / 2,
        endAngle: -.pi / 2 + 2 * .pi * clamped,
        clockwise: true
      )
      path.closeSubpath()
      pieLayer.path = path
    }

    private func updateColors() {
      trackLayer.strokeColor = color.withAlphaComponent(0.3).cgColor
      pieLayer.fillColor = color.cgColor
    }
  }
#endif
