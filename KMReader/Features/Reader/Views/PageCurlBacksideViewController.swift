//
// PageCurlBacksideViewController.swift
//

#if os(iOS)
  import UIKit

  final class PageCurlBacksideViewController: UIViewController {
    struct Style {
      let baseColor: UIColor
      let fillOpacity: CGFloat
      let dimOpacity: CGFloat

      init(
        baseColor: UIColor,
        fillOpacity: CGFloat = 0.95,
        dimOpacity: CGFloat = 0
      ) {
        self.baseColor = baseColor
        self.fillOpacity = Self.clamp(fillOpacity)
        self.dimOpacity = Self.clamp(dimOpacity)
      }

      var renderedColor: UIColor {
        baseColor.withAlphaComponent(fillOpacity)
      }

      private static func clamp(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
      }
    }

    let destinationToken: String
    private var style: Style
    private let dimView = UIView()

    init(destinationToken: String, style: Style) {
      self.destinationToken = destinationToken
      self.style = style
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
      let baseView = UIView()
      baseView.backgroundColor = .clear
      dimView.translatesAutoresizingMaskIntoConstraints = false
      dimView.isUserInteractionEnabled = false
      baseView.addSubview(dimView)
      NSLayoutConstraint.activate([
        dimView.topAnchor.constraint(equalTo: baseView.topAnchor),
        dimView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
        dimView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
        dimView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
      ])
      view = baseView
      applyStyle()
    }

    func updateStyle(_ style: Style) {
      self.style = style
      if isViewLoaded {
        applyStyle()
      }
    }

    private func applyStyle() {
      view.backgroundColor = style.renderedColor
      dimView.backgroundColor = UIColor.black.withAlphaComponent(style.dimOpacity)
    }

    static func applyStyle(_ style: Style, to pageViewController: UIPageViewController) {
      let color = style.renderedColor
      pageViewController.view.backgroundColor = color
      for subview in pageViewController.view.subviews {
        subview.backgroundColor = color
      }
    }
  }
#endif
